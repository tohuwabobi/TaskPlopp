if (-not ('TaskPlopp.MessageBar' -as [type])) {
    Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Windows.Forms;
namespace TaskPlopp {
    public sealed class MessageBar : Control {
        private readonly string[] lines = { "", "" };
        private readonly float[] widths = new float[2];
        private readonly float[] offsets = new float[2];
        private readonly Timer timer;
        private string activity = "";
        private readonly float[] peaks = new float[64];
        private int frame;
        public void SetActivity(string mode, string detail) {
            SetMessage(mode == "Recording" ? "Success" : "Notice",
                mode == "Recording" ? "Diktat laeuft" : "Transkription laeuft",detail);
            activity=mode; Array.Clear(peaks,0,peaks.Length); frame=0;
        }
        public void UpdateActivity(float peak, double seconds) {
            if(activity=="") return;
            frame++;
            if(activity=="Recording") {
                lines[0]="Diktat laeuft - " + TimeSpan.FromSeconds(seconds).ToString(@"hh\:mm\:ss");
                Array.Copy(peaks,1,peaks,0,peaks.Length-1); peaks[peaks.Length-1]=peak;
            }
            Invalidate();
        }
        public bool IsScrolling { get { return timer.Enabled; } }
        public void SetHostVisible(bool visible) {
            if (visible) MeasureLines(); else timer.Stop();
        }
        public MessageBar() {
            DoubleBuffered = true;
            SetStyle(ControlStyles.ResizeRedraw, true);
            timer = new Timer { Interval = 30 };
            timer.Tick += delegate {
                for (int i=0; i<2; i++) {
                    if (widths[i] > ClientSize.Width - 16) offsets[i] = (offsets[i] + 1.5f) % (widths[i] + 48);
                }
                Invalidate();
            };
            ForeColor = Color.FromArgb(30,30,30);
        }
        public void SetMessage(string kind, string summary, string detail) {
            activity="";
            string prefix;
            switch (kind) {
                case "Success": prefix="Erfolg"; BackColor=Color.FromArgb(205,239,211); break;
                case "Error": prefix="Fehler"; BackColor=Color.FromArgb(255,198,198); break;
                case "Warning": prefix="Warnung"; BackColor=Color.FromArgb(255,198,198); break;
                default: prefix="Hinweis"; BackColor=Color.FromArgb(255,226,163); break;
            }
            lines[0] = prefix + ": " + (summary ?? "").Replace('\r',' ').Replace('\n',' ');
            lines[1] = (detail ?? "").Replace('\r',' ').Replace('\n',' ');
            MeasureLines();
        }
        private void MeasureLines() {
            if (timer == null || IsDisposed) return;
            Height = 2 * (Font.Height + 6) + 4;
            using (Graphics g = CreateGraphics()) {
                for (int i=0; i<2; i++) {
                    widths[i] = g.MeasureString(lines[i], Font, Int32.MaxValue, StringFormat.GenericTypographic).Width;
                    offsets[i] = 0;
                }
            }
            timer.Enabled = Visible && ClientSize.Width > 16 && (widths[0] > ClientSize.Width-16 || widths[1] > ClientSize.Width-16);
            Invalidate();
        }
        protected override void OnFontChanged(EventArgs e) { base.OnFontChanged(e); MeasureLines(); }
        protected override void OnResize(EventArgs e) { base.OnResize(e); MeasureLines(); }
        protected override void OnVisibleChanged(EventArgs e) { base.OnVisibleChanged(e); MeasureLines(); }
        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e);
            using (var brush = new SolidBrush(ForeColor)) {
                for (int i=0; i<2; i++) {
                    int top = 2 + i*(Font.Height+6);
                    if(i==1 && activity=="Recording") {
                        float step=Math.Max(1,(ClientSize.Width-16f)/peaks.Length);
                        using(var pen=new Pen(Color.FromArgb(25,110,45),2)) {
                            for(int n=0;n<peaks.Length;n++) {
                                float size=Math.Max(1,peaks[n]*(Font.Height+3));
                                e.Graphics.DrawLine(pen,8+n*step,top+(Font.Height-size)/2,8+n*step,top+(Font.Height+size)/2);
                            }
                        }
                        continue;
                    }
                    var saved = e.Graphics.Save();
                    e.Graphics.SetClip(new Rectangle(8, top, Math.Max(0, ClientSize.Width-16), Font.Height+6));
                    e.Graphics.DrawString(lines[i], Font, brush, 8-offsets[i], top, StringFormat.GenericTypographic);
                    if (widths[i] > ClientSize.Width-16) {
                        e.Graphics.DrawString(lines[i], Font, brush, 8-offsets[i]+widths[i]+48, top, StringFormat.GenericTypographic);
                    }
                    e.Graphics.Restore(saved);
                }
                if(activity=="Transcribing") {
                    int width=Math.Max(1,ClientSize.Width-16);
                    e.Graphics.FillRectangle(Brushes.DarkOrange,8+(frame*5)%width,Height-3,Math.Min(24,width),3);
                }
            }
        }
        protected override void Dispose(bool disposing) {
            if (disposing && timer != null) timer.Dispose();
            base.Dispose(disposing);
        }
    }
}
'@
}

function Set-TaskPloppMessage([string]$Kind, [string]$Summary, [string]$Detail = '') {
    $script:MessageBar.SetMessage($Kind,$Summary,$Detail)
}
