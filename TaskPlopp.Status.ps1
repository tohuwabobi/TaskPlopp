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
                    var saved = e.Graphics.Save();
                    e.Graphics.SetClip(new Rectangle(8, top, Math.Max(0, ClientSize.Width-16), Font.Height+6));
                    e.Graphics.DrawString(lines[i], Font, brush, 8-offsets[i], top, StringFormat.GenericTypographic);
                    if (widths[i] > ClientSize.Width-16) {
                        e.Graphics.DrawString(lines[i], Font, brush, 8-offsets[i]+widths[i]+48, top, StringFormat.GenericTypographic);
                    }
                    e.Graphics.Restore(saved);
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
