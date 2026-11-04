# Local selection shortcuts belong only to the active main window.
if (-not ('TaskPlopp.KeyboardForm' -as [type])) {
    Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Windows.Forms;
namespace TaskPlopp {
    public sealed class KeyboardForm : Form {
        private const string SelectionKeys = "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        private readonly List<Button> selections = new List<Button>();
        public void ClearSelectionButtons() { selections.Clear(); }
        public void RegisterSelectionButton(Button button) {
            int index = selections.Count;
            selections.Add(button);
            if (index < SelectionKeys.Length) button.Text = "[" + SelectionKeys[index] + "]  " + button.Text;
        }
        public bool TrySelectKey(Keys keyData) {
            if (!Visible || !Enabled || Form.ActiveForm != this) return false;
            if ((keyData & (Keys.Control | Keys.Alt)) != Keys.None) return false;
            // Preserve keyboard navigation while a button's context menu is open.
            foreach (Button candidate in selections) {
                if (!candidate.IsDisposed && candidate.ContextMenuStrip != null && candidate.ContextMenuStrip.Visible) return false;
            }
            int code = (int)(keyData & Keys.KeyCode);
            char key;
            if (code >= (int)Keys.D0 && code <= (int)Keys.D9) key = (char)('0' + code - (int)Keys.D0);
            else if (code >= (int)Keys.NumPad0 && code <= (int)Keys.NumPad9) key = (char)('0' + code - (int)Keys.NumPad0);
            else if (code >= (int)Keys.A && code <= (int)Keys.Z) key = (char)code;
            else return false;
            int index = SelectionKeys.IndexOf(key);
            if (index < 0 || index >= selections.Count) return false;
            Button button = selections[index];
            if (button.IsDisposed || !button.Visible || !button.Enabled) return false;
            button.PerformClick();
            return true;
        }
        protected override bool ProcessCmdKey(ref Message msg, Keys keyData) {
            if (TrySelectKey(keyData)) return true;
            return base.ProcessCmdKey(ref msg, keyData);
        }
    }
}
'@
}
