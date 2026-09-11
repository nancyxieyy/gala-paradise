namespace Gala;
static class Program {
    [STAThread]static void Main(string[] args){
        using var mutex=new Mutex(true,"Local\\GalaParadise.Desktop"+(args.Contains("--blind-playtest")?Guid.NewGuid().ToString():""),out bool created);
        if(!created){MessageBox.Show("旮旯乐园已经在运行。点右下角的小蟑螂图标打开面板。","旮旯乐园");return;}
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new Paradise(args.Contains("--smoke-test")));
    }
}
