using System.Drawing.Imaging;
using System.Runtime.InteropServices;
namespace Gala;
sealed class PetWindow:Form {
    public Resident Resident;
    public bool LastRenderOK;
    readonly Action<Guid> use;
    public PetWindow(Resident r,Action<Guid> use){Resident=r;this.use=use;FormBorderStyle=FormBorderStyle.None;ShowInTaskbar=false;TopMost=true;AutoScaleMode=AutoScaleMode.None;ClientSize=new(110,110);StartPosition=FormStartPosition.Manual;}
    protected override bool ShowWithoutActivation=>true;
    protected override CreateParams CreateParams{get{var p=base.CreateParams;p.ExStyle|=0x80000|0x80|0x08000000;return p;}}
    protected override void OnMouseDown(MouseEventArgs e){if(e.Button==MouseButtons.Left)use(Resident.Id);}
    public void Render(double now){
        using var bmp=new Bitmap(110,110,PixelFormat.Format32bppPArgb);using(var g=Graphics.FromImage(bmp)){
            if(Resident.EntryFrame is Rectangle frame&&now<Resident.EntryUntil)g.SetClip(new RectangleF(frame.X-Resident.X,frame.Y-Resident.Y,frame.Width,frame.Height),System.Drawing.Drawing2D.CombineMode.Exclude);
            float size=Rules.Size(Resident.Kind);Art.Bug(g,new((110-size)/2,110-size,size,size),Resident.Kind,now,Resident.FlyingUntil>now,Resident.Direction);
            if(Resident.TauntUntil>now){Art.Round(g,new(0,1,110,24),Art.Cream,9);Art.Text(g,Resident.FlyingUntil>now?"打不到～我会飞！":"你以为没有了？",7,4,11,Art.Ink,true,103);}
        }
        var screenDC=GetDC(IntPtr.Zero);var mem=CreateCompatibleDC(screenDC);var bitmap=bmp.GetHbitmap(Color.FromArgb(0));var old=SelectObject(mem,bitmap);
        try{var pos=new NativePoint((int)Resident.X,(int)Resident.Y);var size=new NativeSize(110,110);var source=new NativePoint(0,0);var blend=new Blend{Alpha=255,Format=1};LastRenderOK=UpdateLayeredWindow(Handle,screenDC,ref pos,ref size,mem,ref source,0,ref blend,2);}
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
    readonly Paradise host;readonly List<(Button Button,Rectangle Bounds)> controls=[];readonly Dictionary<Tool,Button> tools=[];
    Button? pause,quiet,explorer;
    public Dashboard(Paradise host,Icon icon){
        this.host=host;Text="旮旯乐园 · Gala Paradise";Icon=icon;BackColor=Art.Cream;DoubleBuffered=true;AutoScaleMode=AutoScaleMode.None;FormBorderStyle=FormBorderStyle.FixedSingle;MaximizeBox=false;StartPosition=FormStartPosition.CenterScreen;
        var area=Screen.PrimaryScreen!.WorkingArea;float s=Math.Min(1,Math.Min((area.Width-60)/980f,(area.Height-70)/748f));ClientSize=new((int)(980*s),(int)(748*s));
        Add("＋ 撒点面包屑",new(55,281,162,43),()=>host.Action(()=>host.Game.Feed(Paradise.Now)),true);
        Add("放它们去桌面 ↗",new(229,281,172,43),()=>{host.Release();Hide();});
        Add("▰  工作资料",new(62,408,164,60),()=>host.Action(()=>host.Game.Folder(Paradise.Now,PointToScreen(new(100,430)),"preview:工作资料",Bounds))).BackColor=Color.FromArgb(237,206,145);
        Add("▰  绝对干净",new(244,408,164,60),()=>host.Action(()=>host.Game.Folder(Paradise.Now,PointToScreen(new(300,430)),"preview:绝对干净",Bounds))).BackColor=Color.FromArgb(237,206,145);
        explorer=Add("连接资源管理器",new(701,442,222,33),()=>host.Action(()=>{host.Game.State.Explorer=!host.Game.State.Explorer;host.Game.Message=host.Game.State.Explorer?"已连接；打开文件夹试试":"文件夹联动已关闭";}));
        Add("生长速度 ↗",new(720,507,105,28),()=>host.ShowGrowth());
        Add("杀毒扫描",new(833,507,105,28),()=>host.Action(()=>host.Game.Scan(Paradise.Now)));
        foreach(Tool t in Enum.GetValues<Tool>()){var tool=t;tools[t]=Add(Rules.Names[(int)t],new(40+(int)t*183,537,172,62),()=>host.Action(()=>host.Game.Select(tool)));}
        pause=Add("暂停桌宠",new(613,672,106,35),()=>host.Action(()=>host.Game.TogglePause(Paradise.Now)));
        quiet=Add("专注模式",new(727,672,106,35),()=>host.Action(()=>host.Game.State.Quiet=!host.Game.State.Quiet));
        Add("收起面板 ↗",new(841,672,99,35),Hide);
        FormClosing+=(s,e)=>{if(!host.Quitting){e.Cancel=true;Hide();}};
        Resize+=(s,e)=>LayoutButtons();LayoutButtons();RefreshState();
    }
    Button Add(string title,Rectangle bounds,Action action,bool primary=false){var b=new Button{Text=title,FlatStyle=FlatStyle.Flat,BackColor=primary?Art.Moss:Color.FromArgb(232,233,219),ForeColor=primary?Art.Cream:Art.Ink,Cursor=Cursors.Hand,AccessibleName=title};b.FlatAppearance.BorderSize=0;b.Click+=(s,e)=>action();Controls.Add(b);controls.Add((b,bounds));return b;}
    void LayoutButtons(){if(WindowState==FormWindowState.Minimized||ClientSize.Width<200||ClientSize.Height<200)return;float s=ClientSize.Width/980f;foreach(var (b,r) in controls){b.Bounds=new((int)(r.X*s),(int)(r.Y*s),(int)(r.Width*s),(int)(r.Height*s));var old=b.Font;b.Font=new Font("Microsoft YaHei UI",(r.Height<40?12:14)*s,FontStyle.Bold,GraphicsUnit.Pixel);if(!ReferenceEquals(old,DefaultFont))old.Dispose();}}
    public void RefreshState(){var g=host.Game;foreach(var (t,b) in tools){bool unlocked=g.State.Xp>=Rules.Unlock[(int)t];b.Text=unlocked?Rules.Names[(int)t]+(g.State.Tool==t?" ✓":""):$"{Rules.Names[(int)t]} · {Rules.Unlock[(int)t]} 点";b.BackColor=g.State.Tool==t?Art.Moss:Color.FromArgb(232,233,219);b.ForeColor=g.State.Tool==t?Art.Cream:unlocked?Art.Ink:Color.Gray;}
        if(pause!=null)pause.Text=g.Paused?"继续桌宠":"暂停桌宠";if(quiet!=null)quiet.Text=g.State.Quiet?"专注中 ✓":"专注模式";if(explorer!=null)explorer.Text=g.State.Explorer?"资源管理器已连接 ✓":"连接资源管理器 ↗";Invalidate();}
    protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);var g=e.Graphics;float scale=ClientSize.Width/980f;g.ScaleTransform(scale,scale);g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;var state=host.Game.State;
        Art.Text(g,"旮旯乐园",40,29,25,null,true);Art.Text(g,"G A L A   P A R A D I S E",41,64,9,Art.Moss,true);
        Art.Round(g,new(737,36,203,31),Color.FromArgb(231,233,218),15);Art.Text(g,host.Game.Paused?"全体暂停 · 可以安心办公":"桌面生态运行中 · 本地存档",750,43,11);
        Art.Line(g,Color.FromArgb(221,222,207),1,new(40,93),new(940,93));
        Art.Round(g,new(40,114,900,233),Color.FromArgb(232,235,217),22);Art.Text(g,"一只旮杂，整台电脑的热闹。",56,133,11,Art.Moss,true);Art.Text(g,"欢迎入住，",54,158,35,null,true);Art.Text(g,"你的电脑有新房客。",54,200,35,null,true);Art.Text(g,"喂一点，养一窝。清干净了？它可不这么想。",57,253,13,Color.Gray);
        Art.Oval(g,Color.FromArgb(215,220,194),674,167,208,150);Art.Bug(g,new(682,132,192,192),phase:Paradise.Now);Art.Round(g,new(810,143,94,30),Art.Cream,13);Art.Text(g,"你好，室友。",821,149,11);Art.Text(g,"NO. 001 / 旮杂",721,316,10,Art.Moss,true);
        Art.Text(g,"01  /  文件夹栖息地",40,367,15,null,true);Art.Text(g,"点开看看，里面可能有惊喜。",40,389,11,Color.Gray);
        Art.Text(g,state.Poisoned?"已投药 · 成虫躺平，卵仍然会孵化":"试玩文件夹 · 点击即有旮杂跑出来",64,478,11,state.Poisoned?Art.Orange:Color.Gray);
        Art.Round(g,new(446,372,494,117),Color.FromArgb(239,238,228),17);int[] counts=[state.Residents.Count(r=>r.Live),state.Residents.Count(r=>r.Kind==Kind.Egg),state.Residents.Count(r=>r.Kind is Kind.Stain or Kind.Corpse)];string[] names=["住客","卵窝","待清洁"];for(int i=0;i<3;i++){Art.Text(g,counts[i].ToString(),468+i*80,388,25,null,true);Art.Text(g,names[i],468+i*80,422,10,Color.Gray);}
        Art.Text(g,"藏进资源管理器",701,388,15,null,true);Art.Text(g,"打开文件夹时，从窗口附近溜出来。",701,416,10,Color.Gray, false,225);
        Art.Text(g,"02  /  旮杂应对工具箱",40,510,15,null,true);Art.Text(g,$"生长 {state.Habitat.Rate}×",600,514,11,Art.Moss);
        for(int i=0;i<5;i++)Art.Text(g,Rules.Details[i],45+i*183,607,10,Color.Gray,false,171);
        Art.Line(g,Color.FromArgb(221,222,207),1,new(40,641),new(940,641));Art.Text(g,$"LV.{Math.Min(5,state.Xp/10+1)}  共生计划",40,660,12,Art.Moss,true);Art.Text(g,$"{state.Xp} 生长点",199,662,11,Art.Moss);Art.Round(g,new(40,686,234,5),Color.FromArgb(223,225,209),2);if(state.Xp>0)Art.Round(g,new(40,686,234*Math.Min(1,state.Xp/28f),5),Art.Moss,2);
        Art.Text(g,state.Xp>=28?"全工具已解锁 · 旮杂永远有下一招":"喂食、捕捉或清洁，解锁更多工具",40,700,10,Color.Gray);Art.Text(g,host.Game.Message,300,665,12,Art.Orange,false,302);Art.Text(g,Rules.Details[(int)state.Tool],300,689,10,Color.Gray,false,302);
        Art.Text(g,"右下角蟑螂图标随时换工具 · 藏在折叠菜单里时点 ∧ 找到它 · 退出后桌宠和污渍全部隐藏",40,728,9,Color.Gray);
    }
}
sealed class Paradise:ApplicationContext {
    public static double Now=>DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()/1000.0;
    public readonly Game Game=new(Now);
    public bool Quitting;
    readonly bool smoke;
    readonly Dashboard dashboard;readonly NotifyIcon tray;readonly Icon icon;readonly System.Windows.Forms.Timer timer=new(){Interval=33};readonly ExplorerWatcher explorer=new();
    readonly Dictionary<Guid,PetWindow> pets=[];
    readonly string savePath=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"GalaParadise","save.json");
    double lastTick=Now,lastSecond=Now,lastSave=Now;
    public Paradise(bool smoke=false){
        this.smoke=smoke;
        Game.Screens=Screen.AllScreens.Select(s=>s.Bounds).ToArray();
        try{if(!smoke&&File.Exists(savePath))Game.Restore(File.ReadAllText(savePath));}catch(Exception){try{File.Copy(savePath,savePath+".corrupt-"+DateTime.Now.ToString("yyyyMMddHHmmss"));}catch{}Game.Message="旧存档无法读取，已尝试备份";}
        if(Game.State.Residents.Count==0&&Game.State.Xp==0){Game.Spawn(Kind.Adult,Now);Game.Spawn(Kind.Baby,Now);}foreach(var r in Game.State.Residents)if(r.Live)r.Hidden=true;
        using var stream=typeof(Paradise).Assembly.GetManifestResourceStream("GalaParadise.Assets.AppIcon.ico")!;icon=new Icon(stream);
        dashboard=new(this,icon);tray=new NotifyIcon{Icon=icon,Visible=true,Text="旮旯乐园 · 点击换工具"};tray.MouseClick+=(s,e)=>{if(e.Button==MouseButtons.Left)tray.ContextMenuStrip?.Show(Cursor.Position);};tray.DoubleClick+=(s,e)=>ShowDashboard();RebuildMenu();dashboard.Show();Sync();timer.Tick+=(s,e)=>Tick();timer.Start();
        Microsoft.Win32.SystemEvents.DisplaySettingsChanged+=DisplayChanged;
        if(smoke)dashboard.BeginInvoke(new Action(SmokeTest));
    }
    void DisplayChanged(object? s,EventArgs e){if(dashboard.IsDisposed)return;dashboard.BeginInvoke(()=>{Game.Screens=Screen.AllScreens.Select(s=>s.Bounds).ToArray();foreach(var r in Game.State.Residents){if(r.Live)r.Hidden=true;else{var f=Game.Screens[0];r.X=Math.Clamp(r.X,f.Left,f.Right-110);r.Y=Math.Clamp(r.Y,f.Top,f.Bottom-150);}}Game.NextAppearance=Now+8;Sync();});}
    void ShowDashboard(){dashboard.Show();dashboard.WindowState=FormWindowState.Normal;dashboard.Activate();}
    public void Action(Action action){action();Sync();dashboard.RefreshState();RebuildMenu();Save();}
    public void Release(){Action(()=>{if(Game.Paused)Game.TogglePause(Now);var r=Game.State.Residents.FirstOrDefault(r=>r.Live);if(r!=null)Game.BeginVisit(r,Now);else Game.Spawn(Kind.Adult,Now);});}
    public void ShowGrowth(){var menu=new ContextMenuStrip();foreach(var rate in new[]{.25,1.0,3.0}){var r=rate;menu.Items.Add($"生长速度 {r}×",null,(s,e)=>Action(()=>Game.State.Habitat.Rate=r));}menu.Closed+=(s,e)=>menu.Dispose();menu.Show(Cursor.Position);}
    void RebuildMenu(){var menu=new ContextMenuStrip();menu.Items.Add("当前工具："+Rules.Names[(int)Game.State.Tool]).Enabled=false;menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("打开旮旯乐园",null,(s,e)=>ShowDashboard());foreach(Tool t in Enum.GetValues<Tool>()){var tool=t;var item=new ToolStripMenuItem(Game.State.Xp>=Rules.Unlock[(int)t]?Rules.Names[(int)t]:$"{Rules.Names[(int)t]}（{Rules.Unlock[(int)t]} 点解锁）"){Checked=Game.State.Tool==t};item.Click+=(s,e)=>Action(()=>Game.Select(tool));menu.Items.Add(item);}
        menu.Items.Add(new ToolStripSeparator());menu.Items.Add("撒点面包屑 +3",null,(s,e)=>Action(()=>Game.Feed(Now)));menu.Items.Add(Game.Paused?"继续桌宠":"暂停并隐藏桌宠",null,(s,e)=>Action(()=>Game.TogglePause(Now)));menu.Items.Add(Game.State.Quiet?"关闭专注模式":"开启专注模式",null,(s,e)=>Action(()=>Game.State.Quiet=!Game.State.Quiet));if(Game.State.Poisoned)menu.Items.Add("收起蟑螂药",null,(s,e)=>Action(()=>{Game.State.Poisoned=false;Game.State.Tool=Tool.Pinch;}));menu.Items.Add(new ToolStripSeparator());var growth=new ToolStripMenuItem("生长速度");foreach(var rate in new[]{.25,1.0,3.0}){var r=rate;var item=new ToolStripMenuItem($"{r}×"){Checked=Game.State.Habitat.Rate==r};item.Click+=(s,e)=>Action(()=>Game.State.Habitat.Rate=r);growth.DropDownItems.Add(item);}menu.Items.Add(growth);menu.Items.Add("杀毒扫描 · 清理游戏住客",null,(s,e)=>Action(()=>Game.Scan(Now)));menu.Items.Add("退出旮旯乐园",null,(s,e)=>Quit());
        var old=tray.ContextMenuStrip;tray.ContextMenuStrip=menu;tray.Text="旮旯乐园 · "+Rules.Names[(int)Game.State.Tool];if(old!=null)dashboard.BeginInvoke(new Action(old.Dispose));
    }
    void Tick(){double now=Now;Game.Tick(now,Math.Min(.1,now-lastTick));lastTick=now;Sync();if(now-lastSecond>1){lastSecond=now;if(!Game.Paused&&!Game.State.Quiet&&Game.State.Explorer&&explorer.TryFolder(out var p,out var identity,out var frame)){Game.Folder(now,p,identity,frame);RebuildMenu();}dashboard.RefreshState();}if(now-lastSave>10){lastSave=now;Save();}}
    void Sync(){foreach(var id in pets.Keys.Where(id=>Game.State.Residents.All(r=>r.Id!=id)).ToArray()){pets[id].Dispose();pets.Remove(id);}foreach(var r in Game.State.Residents){if(!pets.TryGetValue(r.Id,out var pet)){pet=new PetWindow(r,id=>Action(()=>Game.Use(id,Now)));pets[r.Id]=pet;}if(Game.Paused||(r.Live&&r.Hidden)){if(pet.Visible)pet.Hide();continue;}if(!pet.Visible)pet.Show();pet.Render(Now);}}
    void Save(){if(smoke)return;try{Directory.CreateDirectory(Path.GetDirectoryName(savePath)!);File.WriteAllText(savePath+".tmp",Game.Serialize());File.Move(savePath+".tmp",savePath,true);}catch(Exception){Game.Message="存档暂时写入失败，请检查磁盘空间";}}
    void SmokeTest(){
        string log=Path.Combine(Path.GetTempPath(),"GalaParadise-smoke.txt");
        try{
            Game.State=new SaveState();Action(()=>Game.Folder(Now));
            if(pets.Count!=3)throw new Exception("Folder windows were not created");
            if(pets.Values.Any(p=>!p.LastRenderOK))throw new Exception("Transparent layered window rendering failed");
            dashboard.WindowState=FormWindowState.Minimized;
            Game.State.Xp=28;Action(()=>Game.Select(Tool.Vacuum));
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
    void Quit(){if(Quitting)return;Quitting=true;timer.Stop();Save();Microsoft.Win32.SystemEvents.DisplaySettingsChanged-=DisplayChanged;foreach(var p in pets.Values)p.Dispose();tray.Visible=false;tray.Dispose();explorer.Dispose();dashboard.Close();icon.Dispose();ExitThread();}
}
