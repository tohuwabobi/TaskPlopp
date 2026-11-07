// Core Audio logic adapted from Tobias' local TDAudioSwitch/main.ps1.
// No CLI, message loop, device monitoring or external dependencies.
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace TaskPloppAudio {
    public sealed class Device {
        public string Id;
        public string Name;
        public string ContainerId;
    }
    [StructLayout(LayoutKind.Sequential)]
    internal struct PropertyKey {
        public Guid Format; public uint Id;
        public PropertyKey(string format, uint id) { Format = new Guid(format); Id = id; }
    }
    // The native union includes a counted pointer (16 bytes on x64, 8 on x86).
    [StructLayout(LayoutKind.Sequential)]
    internal struct CountedPointer { public uint Count; public IntPtr Pointer; }
    [StructLayout(LayoutKind.Explicit)]
    internal struct ValueUnion {
        [FieldOffset(0)] public IntPtr Pointer;
        [FieldOffset(0)] public long Number;
        [FieldOffset(0)] public CountedPointer Counted;
    }
    [StructLayout(LayoutKind.Sequential)]
    internal struct PropVariant { public ushort Type, Reserved1, Reserved2, Reserved3; public ValueUnion Value; }

    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    internal class EnumeratorObject { }
    [ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")]
    internal class PolicyObject { }
    [ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface Enumerator {
        [PreserveSig] int EnumAudioEndpoints(int flow, uint state, out Collection devices);
        [PreserveSig] int GetDefaultAudioEndpoint(int flow, int role, out Endpoint device);
    }
    [ComImport, Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface Collection {
        [PreserveSig] int GetCount(out uint count);
        [PreserveSig] int Item(uint index, out Endpoint device);
    }
    [ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface Endpoint {
        [PreserveSig] int Activate(ref Guid iid, uint context, IntPtr parameters, out IntPtr result);
        [PreserveSig] int OpenPropertyStore(uint access, out PropertyStore properties);
        [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string id);
        [PreserveSig] int GetState(out uint state);
    }
    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface PropertyStore {
        [PreserveSig] int GetCount(out uint count);
        [PreserveSig] int GetAt(uint index, out PropertyKey key);
        [PreserveSig] int GetValue(ref PropertyKey key, out PropVariant value);
        [PreserveSig] int SetValue(ref PropertyKey key, ref PropVariant value);
        [PreserveSig] int Commit();
    }
    [ComImport, Guid("F8679F50-850A-41CF-9C72-430F290290C8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface Policy {
        // Unused methods occupy the native vtable slots before SetDefaultEndpoint.
        [PreserveSig] int GetMixFormat();
        [PreserveSig] int GetDeviceFormat();
        [PreserveSig] int ResetDeviceFormat();
        [PreserveSig] int SetDeviceFormat();
        [PreserveSig] int GetProcessingPeriod();
        [PreserveSig] int SetProcessingPeriod();
        [PreserveSig] int GetShareMode();
        [PreserveSig] int SetShareMode();
        [PreserveSig] int GetPropertyValue();
        [PreserveSig] int SetPropertyValue();
        [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string id, int role);
    }
    public static class Audio {
        [DllImport("ole32.dll")] private static extern int PropVariantClear(ref PropVariant value);
        private static void Release(object value) { if (value != null) Marshal.ReleaseComObject(value); }
        private static void CheckFlow(int flow) { if (flow < 0 || flow > 1) throw new ArgumentOutOfRangeException("flow"); }
        private static void CheckRole(int role) { if (role < 0 || role > 2) throw new ArgumentOutOfRangeException("role"); }
        private static string Property(PropertyStore store, PropertyKey key) {
            PropVariant value;
            Marshal.ThrowExceptionForHR(store.GetValue(ref key, out value));
            try {
                if (value.Value.Pointer == IntPtr.Zero) return "";
                if (value.Type == 31) return Marshal.PtrToStringUni(value.Value.Pointer) ?? "";
                if (value.Type == 72) return ((Guid)Marshal.PtrToStructure(value.Value.Pointer, typeof(Guid))).ToString("D");
                return "";
            } finally { PropVariantClear(ref value); }
        }
        public static Device[] GetDevices(int flow) {
            CheckFlow(flow);
            Enumerator enumerator = null; Collection devices = null;
            try {
                enumerator = (Enumerator)new EnumeratorObject();
                Marshal.ThrowExceptionForHR(enumerator.EnumAudioEndpoints(flow, 1, out devices));
                uint count; Marshal.ThrowExceptionForHR(devices.GetCount(out count));
                var result = new List<Device>();
                for (uint i=0; i<count; i++) {
                    Endpoint endpoint = null; PropertyStore store = null;
                    try {
                        Marshal.ThrowExceptionForHR(devices.Item(i, out endpoint));
                        string id; Marshal.ThrowExceptionForHR(endpoint.GetId(out id));
                        Marshal.ThrowExceptionForHR(endpoint.OpenPropertyStore(0, out store));
                        string name = Property(store, new PropertyKey("A45C254E-DF1C-4EFD-8020-67D146A850E0", 14));
                        string container = "";
                        try { container = Property(store, new PropertyKey("8C7ED206-3F8A-4827-B3AB-AE9E1FAEFC6C", 2)); }
                        catch (COMException) { } // Optional metadata; names remain a color fallback.
                        result.Add(new Device { Id=id, Name=String.IsNullOrEmpty(name) ? id : name, ContainerId=container });
                    } finally { Release(store); Release(endpoint); }
                }
                return result.ToArray();
            } finally { Release(devices); Release(enumerator); }
        }
        public static string GetDefaultId(int flow, int role) {
            CheckFlow(flow); CheckRole(role);
            Enumerator enumerator = null; Endpoint endpoint = null;
            try {
                enumerator = (Enumerator)new EnumeratorObject();
                int hr = enumerator.GetDefaultAudioEndpoint(flow, role, out endpoint);
                if (hr == unchecked((int)0x80070490)) return ""; // No default endpoint.
                Marshal.ThrowExceptionForHR(hr);
                string id; Marshal.ThrowExceptionForHR(endpoint.GetId(out id));
                return id;
            } finally { Release(endpoint); Release(enumerator); }
        }
        public static void SetDefaultId(string id, int role) {
            CheckRole(role);
            if (String.IsNullOrWhiteSpace(id)) throw new ArgumentException("Missing endpoint ID");
            Policy policy = null;
            try {
                policy = (Policy)new PolicyObject();
                Marshal.ThrowExceptionForHR(policy.SetDefaultEndpoint(id, role));
            } finally { Release(policy); }
        }
    }
}
