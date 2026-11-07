using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

namespace TaskPlopp.Dictation {
    public sealed class Installer : IDisposable {
        private readonly Process process;
        public volatile string LastLine = "Einrichtung wird gestartet";
        public string Error = "";
        public bool Done { get { return process.HasExited; } }
        public int ExitCode { get { process.WaitForExit(); return process.ExitCode; } }
        public Installer(string script, string root) {
            string shell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "System32\\WindowsPowerShell\\v1.0\\powershell.exe");
            var info = new ProcessStartInfo(shell,"-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\" -Root \"" + root + "\"");
            info.UseShellExecute=false; info.CreateNoWindow=true;
            info.RedirectStandardOutput=info.RedirectStandardError=true;
            info.StandardOutputEncoding=info.StandardErrorEncoding=Encoding.UTF8;
            process=new Process { StartInfo=info };
            process.OutputDataReceived += (s,e) => { if(!String.IsNullOrWhiteSpace(e.Data)) LastLine=e.Data; };
            process.ErrorDataReceived += (s,e) => { if(!String.IsNullOrWhiteSpace(e.Data)) Error += e.Data + " "; };
            process.Start(); process.BeginOutputReadLine(); process.BeginErrorReadLine();
        }
        public void Dispose() {
            try {
                if(!process.HasExited) {
                    // Stop only this installer's process tree, including its engine probe.
                    var info=new ProcessStartInfo(Path.Combine(Environment.SystemDirectory,"taskkill.exe"),"/PID " + process.Id + " /T /F");
                    info.UseShellExecute=false; info.CreateNoWindow=true;
                    info.RedirectStandardOutput=info.RedirectStandardError=true;
                    using(var stop=Process.Start(info)) {
                        var output=stop.StandardOutput.ReadToEndAsync(); var error=stop.StandardError.ReadToEndAsync();
                        stop.WaitForExit(); output.GetAwaiter().GetResult(); error.GetAwaiter().GetResult();
                    }
                }
            } catch(InvalidOperationException) {} finally { process.Dispose(); }
        }
    }
    public sealed class Recorder : IDisposable {
        [StructLayout(LayoutKind.Sequential, Pack = 2)] struct Format {
            public ushort tag, channels; public uint rate, bytes; public ushort align, bits, extra;
        }
        [StructLayout(LayoutKind.Sequential)] struct Header {
            public IntPtr data; public uint length, recorded; public UIntPtr user;
            public uint flags, loops; public IntPtr next; public UIntPtr reserved;
        }
        [DllImport("winmm.dll")] static extern uint waveInGetNumDevs();
        [DllImport("winmm.dll")] static extern uint waveInMessage(IntPtr id, uint message, IntPtr first, IntPtr second);
        [DllImport("winmm.dll")] static extern uint waveInOpen(out IntPtr handle, uint id, ref Format format, IntPtr callback, IntPtr instance, uint flags);
        [DllImport("winmm.dll")] static extern uint waveInPrepareHeader(IntPtr handle, IntPtr header, uint size);
        [DllImport("winmm.dll")] static extern uint waveInUnprepareHeader(IntPtr handle, IntPtr header, uint size);
        [DllImport("winmm.dll")] static extern uint waveInAddBuffer(IntPtr handle, IntPtr header, uint size);
        [DllImport("winmm.dll")] static extern uint waveInStart(IntPtr handle);
        [DllImport("winmm.dll")] static extern uint waveInReset(IntPtr handle);
        [DllImport("winmm.dll")] static extern uint waveInClose(IntPtr handle);
        private IntPtr handle;
        private readonly List<IntPtr> headers = new List<IntPtr>();
        private readonly MemoryStream audio = new MemoryStream();
        private readonly uint headerSize = (uint)Marshal.SizeOf(typeof(Header));
        private volatile float peak;
        private volatile bool capturing;
        private Task pump;
        private string captureError;
        private int nextHeader;
        public float Peak { get { return peak; } }
        public long Bytes { get { lock(audio) return audio.Length; } }
        static void Check(uint code) { if (code != 0) throw new Exception("Mikrofonfehler (WinMM " + code + "). Bitte Audiogeraet und Mikrofonberechtigung pruefen."); }
        static Format PcmFormat() { return new Format { tag=1, channels=1, rate=16000, bytes=32000, align=2, bits=16 }; }
        public static uint DeviceId(string endpoint) {
            for (uint id=0; id<waveInGetNumDevs(); id++) {
                IntPtr size = Marshal.AllocHGlobal(4);
                try {
                    Marshal.WriteInt32(size, 0);
                    if (waveInMessage((IntPtr)id, 0x812, size, IntPtr.Zero) != 0) continue;
                    int bytes = Marshal.ReadInt32(size); if (bytes <= 0 || bytes > 65536) continue;
                    IntPtr name = Marshal.AllocHGlobal(bytes);
                    try {
                        if (waveInMessage((IntPtr)id, 0x811, name, (IntPtr)bytes) == 0 &&
                            String.Equals(Marshal.PtrToStringUni(name), endpoint, StringComparison.OrdinalIgnoreCase)) return id;
                    } finally { Marshal.FreeHGlobal(name); }
                } finally { Marshal.FreeHGlobal(size); }
            }
            throw new Exception("Das ausgewaehlte Standardmikrofon ist nicht als Aufnahmegeraet verfuegbar.");
        }
        public static void CheckFormat(string endpoint) {
            var format = PcmFormat(); IntPtr unused;
            Check(waveInOpen(out unused, DeviceId(endpoint), ref format, IntPtr.Zero, IntPtr.Zero, 1));
        }
        public Recorder(string endpoint) {
            try {
                var format = PcmFormat();
                Check(waveInOpen(out handle, DeviceId(endpoint), ref format, IntPtr.Zero, IntPtr.Zero, 0));
                for (int i=0; i<8; i++) {
                    var h = new Header { data=Marshal.AllocHGlobal(3200), length=3200 };
                    IntPtr pointer=Marshal.AllocHGlobal((int)headerSize); headers.Add(pointer);
                    Marshal.StructureToPtr(h,pointer,false);
                    Check(waveInPrepareHeader(handle,pointer,headerSize));
                    Check(waveInAddBuffer(handle,pointer,headerSize));
                }
                Check(waveInStart(handle));
                capturing=true;
                pump=Task.Run(() => {
                    try { while(capturing) { lock(audio) Drain(true); System.Threading.Thread.Sleep(20); } }
                    catch(Exception e) { captureError=e.Message; capturing=false; }
                });
            } catch { Dispose(); throw; }
        }
        public void Poll() { if(captureError!=null) throw new Exception(captureError); }
        private void Drain(bool requeue) {
            if(requeue && headers.Count>0 && headers.TrueForAll(p => (((Header)Marshal.PtrToStructure(p,typeof(Header))).flags & 1)!=0))
                throw new Exception("Aufnahmepuffer uebergelaufen. Aufnahme wurde verworfen; bitte erneut diktieren.");
            float currentPeak=0; bool received=false;
            for(int n=0;n<headers.Count;n++) {
                IntPtr pointer=headers[nextHeader];
                var h=(Header)Marshal.PtrToStructure(pointer,typeof(Header));
                if ((h.flags & 1) == 0) break;
                nextHeader=(nextHeader+1)%headers.Count;
                received=true;
                var bytes=new byte[h.recorded]; Marshal.Copy(h.data,bytes,0,bytes.Length);
                audio.Write(bytes,0,bytes.Length);
                for (int i=0; i+1<bytes.Length; i+=2) currentPeak=Math.Max(currentPeak,Math.Abs((int)BitConverter.ToInt16(bytes,i))/32768f);
                if(requeue) Check(waveInAddBuffer(handle,pointer,headerSize));
            }
            if(received) peak=currentPeak;
        }
        public byte[] Stop() {
            if(handle==IntPtr.Zero) throw new ObjectDisposedException("Recorder");
            capturing=false; if(pump!=null) pump.Wait(); Poll();
            Check(waveInReset(handle)); Drain(false);
            return audio.ToArray();
        }
        public void Dispose() {
            capturing=false; if(pump!=null) pump.Wait();
            if(handle!=IntPtr.Zero) waveInReset(handle);
            foreach(IntPtr pointer in headers) {
                var h=(Header)Marshal.PtrToStructure(pointer,typeof(Header));
                if(handle!=IntPtr.Zero) waveInUnprepareHeader(handle,pointer,headerSize);
                Marshal.FreeHGlobal(h.data); Marshal.FreeHGlobal(pointer);
            }
            headers.Clear(); if(handle!=IntPtr.Zero) waveInClose(handle);
            handle=IntPtr.Zero; audio.Dispose();
        }
    }
    public sealed class Job : IDisposable {
        public volatile bool Done;
        public string Text = "", Error = "";
        public long Milliseconds;
        private volatile bool cancelled;
        private readonly object gate = new object();
        private Process process;
        public Job(string engine, string executable, string model, byte[] pcm) {
            Task.Run(() => {
                var watch = Stopwatch.StartNew();
                try {
                    if (pcm == null || pcm.Length < 3200) throw new Exception("Aufnahme ist zu kurz.");
                    Text = engine == "Whisper" ? Whisper(executable, model, pcm) : Vosk(executable, model, pcm);
                } catch (Exception e) { Error = e.Message; }
                finally { Milliseconds = watch.ElapsedMilliseconds; Done = true; }
            });
        }
        public static byte[] Wav(byte[] pcm) {
            using (var stream = new MemoryStream()) {
                using (var w = new BinaryWriter(stream, Encoding.ASCII, true)) {
                    w.Write(Encoding.ASCII.GetBytes("RIFF")); w.Write(checked(pcm.Length + 36));
                    w.Write(Encoding.ASCII.GetBytes("WAVEfmt ")); w.Write(16); w.Write((short)1);
                    w.Write((short)1); w.Write(16000); w.Write(32000); w.Write((short)2); w.Write((short)16);
                    w.Write(Encoding.ASCII.GetBytes("data")); w.Write(pcm.Length); w.Write(pcm);
                }
                return stream.ToArray();
            }
        }
        private string Whisper(string exe, string model, byte[] pcm) {
            var start = new ProcessStartInfo(exe, "-m \"" + model + "\" -f - -of taskplopp-stdout -l de -nt -np -ng");
            start.UseShellExecute = false; start.CreateNoWindow = true;
            start.RedirectStandardInput = start.RedirectStandardOutput = start.RedirectStandardError = true;
            start.StandardOutputEncoding = start.StandardErrorEncoding = Encoding.UTF8;
            start.WorkingDirectory = Path.GetDirectoryName(exe);
            using (var p = new Process { StartInfo = start }) {
                lock (gate) { if (cancelled) throw new OperationCanceledException(); p.Start(); process = p; }
                try {
                    var output = p.StandardOutput.ReadToEndAsync();
                    var errors = p.StandardError.ReadToEndAsync();
                    byte[] wav = Wav(pcm);
                    p.StandardInput.BaseStream.Write(wav, 0, wav.Length); p.StandardInput.Close();
                    p.WaitForExit();
                    string text = output.GetAwaiter().GetResult();
                    string diagnostic = errors.GetAwaiter().GetResult();
                    if (p.ExitCode != 0) throw new Exception("whisper.cpp fehlgeschlagen (" + p.ExitCode + "). " + diagnostic);
                    return text.Trim();
                } finally { lock (gate) { process = null; } }
            }
        }
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern IntPtr LoadLibraryEx(string path, IntPtr file, uint flags);
        [DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr module);
        [DllImport("kernel32.dll", CharSet = CharSet.Ansi)] static extern IntPtr GetProcAddress(IntPtr module, string name);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr ModelNew(byte[] path);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr RecognizerNew(IntPtr model, float rate);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void Release(IntPtr value);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Accept(IntPtr r, byte[] data, int length);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr Result(IntPtr r);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate void LogLevel(int level);
        static T Function<T>(IntPtr module, string name) where T : class {
            IntPtr address = GetProcAddress(module, name);
            if (address == IntPtr.Zero) throw new Exception("Vosk-Funktion fehlt: " + name);
            return Marshal.GetDelegateForFunctionPointer(address, typeof(T)) as T;
        }
        static string Utf8(IntPtr pointer) {
            int length = 0; while (Marshal.ReadByte(pointer, length) != 0) length++;
            byte[] bytes = new byte[length]; Marshal.Copy(pointer, bytes, 0, length);
            return Encoding.UTF8.GetString(bytes);
        }
        public static string JoinResults(IEnumerable<string> results) {
            var parts = new List<string>(); var json = new JavaScriptSerializer();
            foreach (string result in results) {
                var fields = json.Deserialize<Dictionary<string, object>>(result);
                object text; if (fields.TryGetValue("text", out text) && text is string && !String.IsNullOrWhiteSpace((string)text)) parts.Add(((string)text).Trim());
            }
            return String.Join(" ", parts);
        }
        private string Vosk(string dll, string modelPath, byte[] pcm) {
            IntPtr module = LoadLibraryEx(dll, IntPtr.Zero, 8);
            if (module == IntPtr.Zero) throw new Exception("Vosk-DLL konnte nicht geladen werden. Windows-Fehler " + Marshal.GetLastWin32Error());
            IntPtr model = IntPtr.Zero, r = IntPtr.Zero;
            try {
                Function<LogLevel>(module, "vosk_set_log_level")(-1);
                model = Function<ModelNew>(module, "vosk_model_new")(Encoding.UTF8.GetBytes(modelPath + "\0"));
                if (model == IntPtr.Zero) throw new Exception("Vosk-Modell konnte nicht geladen werden.");
                r = Function<RecognizerNew>(module, "vosk_recognizer_new")(model, 16000);
                if (r == IntPtr.Zero) throw new Exception("Vosk-Erkennung konnte nicht gestartet werden.");
                var accept = Function<Accept>(module, "vosk_recognizer_accept_waveform");
                var result = Function<Result>(module, "vosk_recognizer_result");
                var parts = new List<string>();
                for (int offset = 0; offset < pcm.Length; offset += 8000) {
                    if (cancelled) throw new OperationCanceledException();
                    int length = Math.Min(8000, pcm.Length - offset); var chunk = new byte[length];
                    Buffer.BlockCopy(pcm, offset, chunk, 0, length);
                    int code = accept(r, chunk, length);
                    if (code < 0) throw new Exception("Vosk konnte Audiodaten nicht verarbeiten.");
                    if (code == 1) parts.Add(Utf8(result(r)));
                }
                parts.Add(Utf8(Function<Result>(module, "vosk_recognizer_final_result")(r)));
                return JoinResults(parts);
            } finally {
                if (r != IntPtr.Zero) Function<Release>(module, "vosk_recognizer_free")(r);
                if (model != IntPtr.Zero) Function<Release>(module, "vosk_model_free")(model);
                FreeLibrary(module);
            }
        }
        public void Dispose() {
            cancelled = true;
            lock (gate) { try { if (process != null && !process.HasExited) process.Kill(); } catch(InvalidOperationException) {} }
        }
    }
}
