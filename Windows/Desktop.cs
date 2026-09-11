using System.Drawing.Imaging;
using System.Runtime.InteropServices;
namespace Gala;
sealed class PetWindow:Form {
    public Resident Resident;
    public bool LastRenderOK;
    public bool PlayfulEffect;public Tool? EffectTool;public double EffectBorn;
    readonly Action<Guid> use;readonly Action<Guid>? inspect;
    public PetWindow(Resident r,Action<Guid> use,Action<Guid>? inspect=null){Resident=r;this.use=use;this.inspect=inspect;FormBorderStyle=FormBorderStyle.None;ShowInTaskbar=false;TopMost=true;AutoScaleMode=AutoScaleMode.None;ClientSize=new(Rules.Canvas(r.Kind),Rules.Canvas(r.Kind));StartPosition=FormStartPosition.Manual;}
    protected override bool ShowWithoutActivation=>true;
    protected override CreateParams CreateParams{get{var p=base.CreateParams;p.ExStyle|=0x80000|0x80|0x08000000;if(EffectTool.HasValue)p.ExStyle|=0x20;return p;}}
    protected override void OnMouseDown(MouseEventArgs e){if(e.Button==MouseButtons.Right)inspect?.Invoke(Resident.Id);else use(Resident.Id);}
    public void Render(double now){
        using var bmp=new Bitmap(ClientSize.Width,ClientSize.Height,PixelFormat.Format32bppPArgb);using(var g=Graphics.FromImage(bmp)){
            if(Resident.EntryFrame is Rectangle frame&&now<Resident.EntryUntil)g.SetClip(new RectangleF(frame.X-Resident.X,frame.Y-Resident.Y,frame.Width,frame.Height),System.Drawing.Drawing2D.CombineMode.Exclude);
            if(EffectTool.HasValue)Art.Effect(g,EffectTool.Value,now-EffectBorn,PlayfulEffect);
            else {float size=Rules.Size(Resident.Kind);float bounce=Resident.ReactionUntil>now?(float)Math.Sin((Resident.ReactionUntil-now)*32)*4:0;Art.Bug(g,new((ClientSize.Width-size)/2+bounce,ClientSize.Height-size,size,size),Resident.Kind,Resident.Kind==Kind.CatPaw?now-Resident.Born:now,Resident.FlyingUntil>now,Resident.Direction);
            if(Resident.CarryUntil>now){Art.Round(g,new(ClientSize.Width/2,ClientSize.Height-28,28,23),Art.Cream,3);for(int y=8;y<=14;y+=6)Art.Line(g,Art.Moss,1,new(ClientSize.Width/2+5,ClientSize.Height-28+y),new(ClientSize.Width/2+23,ClientSize.Height-28+y));}
            if(Resident.TauntUntil>now){Art.Round(g,new(0,1,110,24),Art.Cream,9);Art.Text(g,Resident.FlyingUntil>now?"打不到～我会飞！":"你以为没有了？",7,4,11,Art.Ink,true,103);}
        }
        }
        var screenDC=GetDC(IntPtr.Zero);var mem=CreateCompatibleDC(screenDC);var bitmap=bmp.GetHbitmap(Color.FromArgb(0));var old=SelectObject(mem,bitmap);
        try{var pos=new NativePoint((int)Resident.X,(int)Resident.Y);var size=new NativeSize(ClientSize.Width,ClientSize.Height);var source=new NativePoint(0,0);var blend=new Blend{Alpha=255,Format=1};LastRenderOK=UpdateLayeredWindow(Handle,screenDC,ref pos,ref size,mem,ref source,0,ref blend,2);}
        finally{SelectObject(mem,old);DeleteObject(bitmap);DeleteDC(mem);ReleaseDC(IntPtr.Zero,screenDC);}
    }
    [StructLayout(LayoutKind.Sequential)]struct NativePoint{public int X,Y;public NativePoint(int x,int y){X=x;Y=y;}}
    [StructLayout(LayoutKind.Sequential)]struct NativeSize{public int W,H;public NativeSize(int w,int h){W=w;H=h;}}
    [StructLayout(LayoutKind.Sequential,Pack=1)]struct Blend{public byte Operation,Flags,Alpha,Format;}
    [DllImport("user32.dll")]static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")]static extern int ReleaseDC(IntPtr h,IntPtr dc);
    [DllImport("gdi32.dll")]static extern IntPtr CreateCompatibleDC(IntPtr dc);
    [DllImport("gdi32.dll")]static extern bool DeleteDC(IntPtr dc);
    [DllImport("gdi32.dll")]static extern IntPtr SelectObject(IntPtr dc,IntPtr obj);
    [DllImport("gdi32.dll")]static extern bool DeleteObject(IntPtr obj);
    [DllImport("user32.dll")]static extern bool UpdateLayeredWindow(IntPtr h,IntPtr dc,ref NativePoint pt,ref NativeSize size,IntPtr src,ref NativePoint srcPt,uint key,ref Blend blend,uint flags);
}
sealed class Dashboard:Form {
 readonly Paradise host;readonly List<(Button Button,Rectangle Rect)> controls=[];readonly Dictionary<Tool,Button> tools=[];Button pause=null!;
 public Dashboard(Paradise host,Icon icon){this.host=host;Text="旮旯乐园";Icon=icon;BackColor=Art.Cream;DoubleBuffered=true;AutoScaleMode=AutoScaleMode.None;FormBorderStyle=FormBorderStyle.FixedSingle;MaximizeBox=false;StartPosition=FormStartPosition.CenterScreen;ClientSize=new(620,420);
  Add("···",new(548,22,44,40),()=>host.ShowOptions());
  foreach(Tool t in Enum.GetValues<Tool>()){var tool=t;tools[t]=Add(Rules.Names[(int)t],new(28+(int)t*114,245,108,40),()=>host.Action(()=>host.Game.Select(tool)));}
  Add("＋ 喂一点",new(28,318,132,40),()=>host.Action(()=>host.Game.Feed(Paradise.Now)),true);Add("去桌面玩",new(170,318,132,40),()=>{host.Release();Hide();});Add("我的小窝",new(312,318,132,40),()=>host.ShowLife());pause=Add("歇一会儿",new(454,318,138,40),()=>host.Action(()=>host.Game.TogglePause(Paradise.Now)));
  FormClosing+=(s,e)=>{if(!host.Quitting){e.Cancel=true;Hide();}};RefreshState();
 }
 Button Add(string title,Rectangle bounds,Action action,bool primary=false){var b=new Button{Text=title,Bounds=bounds,FlatStyle=FlatStyle.Flat,BackColor=primary?Art.Moss:Color.FromArgb(235,236,221),ForeColor=primary?Art.Cream:Art.Ink,Cursor=Cursors.Hand,Font=new Font("Microsoft YaHei UI",11),AccessibleName=title};b.FlatAppearance.BorderSize=0;b.Click+=(s,e)=>action();Controls.Add(b);controls.Add((b,bounds));return b;}
 public void RefreshState(){var g=host.Game;foreach(var(t,b)in tools){b.Text=Rules.Names[(int)t]+(g.Owns(t)?"":$" · {Rules.Cost[(int)t]} ✦");b.BackColor=g.State.Tool==t?Art.Moss:Color.FromArgb(235,236,221);b.ForeColor=g.State.Tool==t?Art.Cream:Art.Ink;}pause.Text=g.Paused?"继续玩":"歇一会儿";Invalidate();}
 protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);var g=e.Graphics;g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;Art.Text(g,"旮旯乐园",28,26,23,Art.Ink,true);Art.Text(g,"你的桌面，有几个小住客。",29,59,11,Art.Moss);
  Art.Round(g,new(28,96,564,126),Color.FromArgb(232,236,217),22);Art.Text(g,"碰一下，就有回应。",46,119,24,Art.Ink,true);Art.Text(g,"左键用工具，右键交朋友。",47,158,14,Art.Moss);Art.Text(g,host.Game.Paused?"它们在休息":"路过时把鼠标靠近，它会停下来等你。",47,186,11,Art.Moss);Art.Bug(g,new(466,98,115,115),phase:Paradise.Now);
  Art.Text(g,"今天拿什么逗它们？",30,226,11,Art.Moss);Art.Text(g,$"✦ {host.Game.State.Progression.Shells}",525,226,11,Art.Moss,true);Art.Text(g,"旮杂会躲，老鼠会抖毛，猫爪会接招。",30,293,11,Art.Moss);Art.Text(g,host.Game.Message,30,376,12,Art.Moss,false,560);
 }
}
sealed partial class Paradise:ApplicationContext {
    public static double Now=>DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()/1000.0;
    public readonly Game Game=new(Now);
    public bool Quitting;
    readonly bool smoke;
    TraceWindow? traceWindow;
    LifeWindow? lifeWindow;
    readonly Dashboard dashboard;readonly NotifyIcon tray;readonly Icon icon;readonly System.Windows.Forms.Timer timer=new(){Interval=33};readonly ExplorerWatcher explorer=new();
    readonly Dictionary<Guid,PetWindow> pets=[];
    readonly List<(PetWindow Window,double Until)> effects=[];
    readonly string savePath=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"GalaParadise","save.json");
    double lastTick=Now,lastSecond=Now,lastSave=Now;
    public Paradise(bool smoke=false){
        this.smoke=smoke;
        Game.Screens=Screen.AllScreens.Select(s=>s.Bounds).ToArray();
        try{if(!smoke&&File.Exists(savePath)){var json=File.ReadAllText(savePath);using var document=System.Text.Json.JsonDocument.Parse(json);if(!document.RootElement.TryGetProperty("Progression",out _)&&!File.Exists(savePath+".before-1.4"))File.Copy(savePath,savePath+".before-1.4");if(!document.RootElement.TryGetProperty("Life",out _)&&!File.Exists(savePath+".before-1.5"))File.Copy(savePath,savePath+".before-1.5");Game.Restore(json);}}catch(Exception){try{File.Copy(savePath,savePath+".corrupt-"+DateTime.Now.ToString("yyyyMMddHHmmss"));}catch{}Game.Message="旧存档无法读取，已尝试备份";}
        if(Game.State.Residents.Count==0&&Game.State.Xp==0){Game.Spawn(Kind.Adult,Now);Game.Spawn(Kind.Baby,Now);}foreach(var r in Game.State.Residents)if(r.Live)r.Hidden=true;
        using var stream=typeof(Paradise).Assembly.GetManifestResourceStream("GalaParadise.Assets.AppIcon.ico")!;icon=new Icon(stream);
        dashboard=new(this,icon);tray=new NotifyIcon{Icon=icon,Visible=true,Text="旮旯乐园 · 点击换工具"};tray.MouseClick+=(s,e)=>{if(e.Button==MouseButtons.Left)tray.ContextMenuStrip?.Show(Cursor.Position);};tray.DoubleClick+=(s,e)=>ShowDashboard();RebuildMenu();dashboard.Show();Sync();timer.Tick+=(s,e)=>Tick();timer.Start();
        Microsoft.Win32.SystemEvents.DisplaySettingsChanged+=DisplayChanged;
        if(smoke)dashboard.BeginInvoke(new Action(SmokeTest));
    }
    void DisplayChanged(object? s,EventArgs e){if(dashboard.IsDisposed)return;dashboard.BeginInvoke(()=>{Game.Screens=Screen.AllScreens.Select(s=>s.Bounds).ToArray();foreach(var r in Game.State.Residents){if(r.Live)r.Hidden=true;else{var f=Game.Screens[0];r.X=Math.Clamp(r.X,f.Left,f.Right-110);r.Y=Math.Clamp(r.Y,f.Top,f.Bottom-150);}}Game.NextAppearance=Now+8;Sync();});}
    public void ShowLife(){if(lifeWindow==null||lifeWindow.IsDisposed)lifeWindow=new(this);lifeWindow.RefreshState();lifeWindow.Show();lifeWindow.Activate();}
    void ShowDashboard(){dashboard.Show();dashboard.WindowState=FormWindowState.Normal;dashboard.Activate();}
    public void Action(Action action){action();Sync();dashboard.RefreshState();RebuildMenu();Save();}
    public void Release(){Action(()=>{if(Game.Paused)Game.TogglePause(Now);var r=Game.State.Residents.FirstOrDefault(r=>r.Live);if(r!=null)Game.BeginVisit(r,Now);else Game.Spawn(Kind.Adult,Now);});}
    public void ShowOptions(){tray.ContextMenuStrip?.Show(Cursor.Position);}
    public void ShowGrowth(){var menu=new ContextMenuStrip();foreach(var rate in new[]{.25,1.0,3.0}){var r=rate;menu.Items.Add($"生长速度 {r}×",null,(s,e)=>Action(()=>Game.State.Habitat.Rate=r));}menu.Closed+=(s,e)=>menu.Dispose();menu.Show(Cursor.Position);}
    void RebuildMenu(){var menu=new ContextMenuStrip();menu.Items.Add("当前工具："+Rules.Names[(int)Game.State.Tool]).Enabled=false;menu.Items.Add($"黄金卵壳：{Game.State.Progression.Shells}").Enabled=false;menu.Items.Add("新朋友："+(Game.State.Progression.Seen.Count==0?"老鼠 3 分钟 / 猫爪 10 分钟":string.Join("、",Game.State.Progression.Seen.Select(s=>s=="Mouse"?"老鼠":"猫爪")))).Enabled=false;menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("我的小窝 · 伙伴 / 纸条 / 成就",null,(s,e)=>ShowLife());menu.Items.Add("打开旮旯乐园",null,(s,e)=>ShowDashboard());foreach(Tool t in Enum.GetValues<Tool>()){var tool=t;var item=new ToolStripMenuItem(Game.Owns(t)?Rules.Names[(int)t]:$"{Rules.Names[(int)t]}（{Rules.Cost[(int)t]} 金壳解锁）"){Checked=Game.State.Tool==t};item.Click+=(s,e)=>Action(()=>Game.Select(tool));menu.Items.Add(item);}
        menu.Items.Add(new ToolStripSeparator());menu.Items.Add("撒点面包屑 +3",null,(s,e)=>Action(()=>Game.Feed(Now)));menu.Items.Add(Game.Paused?"继续桌宠":"暂停并隐藏桌宠",null,(s,e)=>Action(()=>Game.TogglePause(Now)));menu.Items.Add(Game.State.Quiet?"关闭专注模式":"开启专注模式",null,(s,e)=>Action(()=>Game.State.Quiet=!Game.State.Quiet));if(Game.State.Poisoned)menu.Items.Add("收起蟑螂药",null,(s,e)=>Action(()=>{Game.State.Poisoned=false;Game.State.Tool=Tool.Pinch;}));menu.Items.Add(new ToolStripSeparator());var growth=new ToolStripMenuItem("生长速度");foreach(var rate in new[]{.25,1.0,3.0}){var r=rate;var item=new ToolStripMenuItem($"{r}×"){Checked=Game.State.Habitat.Rate==r};item.Click+=(s,e)=>Action(()=>Game.State.Habitat.Rate=r);growth.DropDownItems.Add(item);}menu.Items.Add(growth);menu.Items.Add("清理游戏痕迹",null,(s,e)=>Action(()=>Game.Scan(Now)));menu.Items.Add(Game.State.Explorer?"断开资源管理器":"连接资源管理器",null,(s,e)=>Action(()=>Game.State.Explorer=!Game.State.Explorer));menu.Items.Add("试玩文件夹",null,(s,e)=>Action(()=>Game.Folder(Now)));menu.Items.Add("退出旮旯乐园",null,(s,e)=>Quit());
        var old=tray.ContextMenuStrip;tray.ContextMenuStrip=menu;tray.Text="旮旯乐园 · "+Rules.Names[(int)Game.State.Tool];if(old!=null)dashboard.BeginInvoke(new Action(old.Dispose));
    }
    void Tick(){double now=Now;foreach(var fx in effects.ToArray()){if(now>=fx.Until||Game.Paused){fx.Window.Dispose();effects.Remove(fx);}else fx.Window.Render(now);}foreach(var r in Game.State.Residents.Where(r=>r.Live&&!r.Hidden)){if(new RectangleF(r.X-8,r.Y-8,Rules.Canvas(r.Kind)+16,Rules.Canvas(r.Kind)+16).Contains(Cursor.Position))r.HoldUntil=now+.3;if(!r.Friend&&Game.State.Life.Bonds.TryGetValue(r.Id.ToString(),out var b)&&b.Fear>0&&Math.Abs(Cursor.Position.X-r.X)+Math.Abs(Cursor.Position.Y-r.Y)<120){r.Exiting=true;r.TargetX=r.X<r.Screen.Left+r.Screen.Width/2?r.Screen.Left-Rules.Canvas(r.Kind):r.Screen.Right;r.TargetY=r.Y;}}
        Game.Tick(now,Math.Min(.1,now-lastTick));lastTick=now;Sync();if(now-lastSecond>1){lastSecond=now;if(!Game.Paused&&!Game.State.Quiet&&Game.State.Explorer&&explorer.TryFolder(out var p,out var identity,out var frame)){Game.Folder(now,p,identity,frame);RebuildMenu();}dashboard.RefreshState();if(lifeWindow?.Visible==true)lifeWindow.RefreshState();}if(now-lastSave>10){lastSave=now;Save();}}
    void Use(Guid id){var before=Game.State.Residents.Find(r=>r.Id==id);var tool=Game.State.Tool;var wasLive=before?.Live==true;
        Action(()=>Game.Use(id,Now));if(before!=null)React(before,Game.Message);
        if(before!=null&&Game.Owns(tool)&&(before.Friend||Game.State.Life.Protects(before.Id)||tool==Tool.Poison||!Game.State.Residents.Contains(before)||(wasLive&&!before.Live))){var r=new Resident{X=before.X,Y=before.Y-20};var fx=new PetWindow(r,_=>{}){EffectTool=tool,EffectBorn=Now,PlayfulEffect=before.Friend||Game.State.Life.Protects(before.Id)};fx.Show();fx.Render(Now);effects.Add((fx,Now+(tool==Tool.Poison?1.15:.55)));}
    }
    void Sync(){
        if(!smoke&&Game.State.Life.TraceReady&&!Game.Paused&&!Game.State.Quiet&&Game.State.Life.FocusRemaining<=0){traceWindow??=new TraceWindow(this);var area=Screen.PrimaryScreen!.WorkingArea;traceWindow.Location=new(area.Right-145,area.Bottom-75);if(!traceWindow.Visible)traceWindow.Show();}else traceWindow?.Hide();
foreach(var id in pets.Keys.Where(id=>Game.State.Residents.All(r=>r.Id!=id)).ToArray()){pets[id].Dispose();pets.Remove(id);}foreach(var r in Game.State.Residents){if(!pets.TryGetValue(r.Id,out var pet)){pet=new PetWindow(r,Use,AnimalMenu);pets[r.Id]=pet;}if(Game.Paused||Game.State.Life.FocusRemaining>0||(r.Live&&r.Hidden)){if(pet.Visible)pet.Hide();continue;}if(!pet.Visible)pet.Show();pet.Render(Now);}}
    void Save(){if(smoke)return;try{Directory.CreateDirectory(Path.GetDirectoryName(savePath)!);File.WriteAllText(savePath+".tmp",Game.Serialize());File.Move(savePath+".tmp",savePath,true);}catch(Exception){Game.Message="存档暂时写入失败，请检查磁盘空间";}}
    void SmokeTest(){
        string log=Path.Combine(Path.GetTempPath(),"GalaParadise-smoke.txt");
        try{
            Game.State=new SaveState();Action(()=>Game.Folder(Now));
            if(pets.Count!=3)throw new Exception("Folder windows were not created");
            if(pets.Values.Any(p=>!p.LastRenderOK))throw new Exception("Transparent layered window rendering failed");
            dashboard.WindowState=FormWindowState.Minimized;
            Game.State.Xp=28;Game.State.Progression.Owned=Enum.GetValues<Tool>().ToList();Action(()=>Game.Select(Tool.Vacuum));
            if(Game.State.Tool!=Tool.Vacuum||tray.ContextMenuStrip==null)throw new Exception("Tray selection failed");
            foreach(var id in Game.State.Residents.Select(r=>r.Id).ToArray())Action(()=>Game.Use(id,Now,1));
            if(pets.Count!=0)throw new Exception("Vacuum did not remove windows");
            ShowDashboard();if(dashboard.WindowState!=FormWindowState.Normal)throw new Exception("Restore failed");
            Game.Spawn(Kind.Adult,Now,new PointF(200,200));Sync();
            Action(()=>Game.TogglePause(Now));if(pets.Values.Any(p=>p.Visible))throw new Exception("Pause failed");
            Action(()=>Game.TogglePause(Now));
            using var preview=new Bitmap(dashboard.ClientSize.Width,dashboard.ClientSize.Height);dashboard.DrawToBitmap(preview,dashboard.ClientRectangle);preview.Save(Path.Combine(Path.GetTempPath(),"GalaParadise-windows-preview.png"));
            File.WriteAllText(log,"PASS: native Windows tray, minimize/restore, folder pets, vacuum, pause and dashboard render");
        }catch(Exception ex){File.WriteAllText(log,ex.ToString());Environment.ExitCode=1;}
        finally{Quit();}
    }
    void Quit(){if(Quitting)return;Quitting=true;timer.Stop();Save();Microsoft.Win32.SystemEvents.DisplaySettingsChanged-=DisplayChanged;foreach(var p in pets.Values)p.Dispose();foreach(var fx in effects)fx.Window.Dispose();foreach(var bubble in reactions.Values.ToArray())bubble.Close();traceWindow?.Dispose();lifeWindow?.Dispose();tray.Visible=false;tray.Dispose();explorer.Dispose();dashboard.Close();icon.Dispose();ExitThread();}
}
