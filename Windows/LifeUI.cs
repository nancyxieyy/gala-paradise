namespace Gala;
sealed class LifeWindow:Form {
 readonly Paradise host;readonly ComboBox guests=new(){DropDownStyle=ComboBoxStyle.DropDownList};readonly ComboBox notes=new(){DropDownStyle=ComboBoxStyle.DropDownList};readonly TextBox input=new();readonly NumericUpDown minutes=new(){Minimum=1,Maximum=120,Value=25};readonly AchievementPanel report=new();
 List<Guid> ids=[];List<string> noteIds=[];
 public LifeWindow(Paradise host){this.host=host;Text="住客手册 · 关系 / 纸条 / 支线 / 成就";ClientSize=new(830,690);BackColor=Art.Cream;StartPosition=FormStartPosition.CenterScreen;AutoScaleMode=AutoScaleMode.Dpi;Font=new Font("Microsoft YaHei UI",10);MinimumSize=new(850,730);
  void Label(string text,int y){Controls.Add(new Label{Text=text,Bounds=new(22,y,790,24)});}
  void Place(Control c,int x,int y,int w,int h){c.Bounds=new(x,y,w,h);Controls.Add(c);}
  void Button(string title,int x,int y,int width,string action){var b=new Button{Text=title,FlatStyle=FlatStyle.Flat,BackColor=Color.FromArgb(232,233,219)};Place(b,x,y,width,32);b.Click+=(s,e)=>Run(action);}
  Label("01 / 熟悉的住客 · 信任 6 可结为伙伴，每 20 秒一次有效互动",18);Place(guests,22,48,650,28);Button("刷新",686,46,120,"refresh");Place(input,22,86,784,28);input.PlaceholderText="输入名字、纸条、链接或领养码（只处理你主动提交的内容）";
  (string,string)[] actions=[("召回","recall"),("摸一摸","pet"),("喂一口","feed"),("取名字","name"),("成为伙伴","bond"),("友好取金壳","gold")];for(int i=0;i<actions.Length;i++)Button(actions[i].Item1,22+i*132,128,124,actions[i].Item2);
  Label("02 / 小窝收纳 · 动物躲起来也能取回，复制不会删除",179);Place(notes,22,210,520,28);Button("收好输入内容",550,208,125,"stash");Button("复制取回",682,208,124,"return");Button("标记 / 取消完成",22,247,160,"done");Button("删除选中纸条",190,247,160,"delete");
  Label("03 / 桌面支线 · 安全窝位于左半屏，巡逻位于右半屏",296);Button("查看脚印 / 探索",22,326,153,"explore");Button("开关安全窝",182,326,174,"safe");Button("请伙伴巡逻",365,326,140,"patrol");Button("安排共居",514,326,132,"coexist");Button("生成领养码",655,326,151,"share");Button("接收输入的领养码",22,369,175,"adopt");Place(minutes,215,371,50,28);Button("分钟 · 开始专注",274,369,150,"focus");Button("结束本次计时",434,369,145,"cancel");
  Label("04 / 成就卡册与动态 · 只记录已完成的事件",423);Place(report,22,453,784,212);RefreshState();
 }
 public void RefreshState(){var g=host.Game;var l=g.State.Life;Guid? old=guests.SelectedIndex>=0?ids[guests.SelectedIndex]:null;ids=g.State.Residents.Where(r=>r.Live&&(l.Bonds.ContainsKey(r.Id.ToString())||!r.Hidden)).Select(r=>r.Id).ToList();guests.Items.Clear();foreach(var id in ids){var r=g.State.Residents.Find(r=>r.Id==id)!;l.Bonds.TryGetValue(id.ToString(),out var b);guests.Items.Add($"{(b?.Name.Length>0?b.Name:r.Kind==Kind.Mouse?"小老鼠":r.Kind==Kind.CatPaw?"猫咪":"旮杂")} · {id.ToString()[..4]} · 信任 {b?.Trust??0} · {(b?.Protected==true?"受保护":"访客")}");}if(ids.Count>0)guests.SelectedIndex=old.HasValue&&ids.Contains(old.Value)?ids.IndexOf(old.Value):0;int ni=notes.SelectedIndex;noteIds=l.Notes.Select(n=>n.Id).ToList();notes.Items.Clear();foreach(var n in l.Notes)notes.Items.Add((n.Done?"✓ ":"○ ")+n.Text[..Math.Min(45,n.Text.Length)].Replace('\n',' '));if(noteIds.Count>0)notes.SelectedIndex=Math.Clamp(ni,0,noteIds.Count-1);
  report.Life=l;report.Message=g.Message;report.Invalidate();report.AccessibleDescription=g.Message+Environment.NewLine+$"\r\n脚印：{(l.TraceReady?"发现碎屑，点探索追踪":"等待住客留下痕迹")} · 安全窝：{(l.SafeLeft?"开启":"关闭")} · 专注剩余：{(int)l.FocusRemaining} 秒\r\n\r\n"+string.Join("\r\n",Life.Achievements.Select(a=>l.Cards.TryGetValue(a.Id,out var date)?$"✓ {a.Name} · {DateTimeOffset.FromUnixTimeSeconds((long)date).ToLocalTime():g}":"○ "+a.Name));
 }
 void Run(string action){if(action!="refresh")host.Action(()=>{host.Game.LifeAction(action,guests.SelectedIndex>=0?ids[guests.SelectedIndex]:null,input.Text,notes.SelectedIndex>=0?noteIds[notes.SelectedIndex]:null,(double)minutes.Value);if(host.Game.ClipboardText is string text){try{Clipboard.SetText(text);}catch(System.Runtime.InteropServices.ExternalException){host.Game.Message="剪贴板忙，请重试复制";}host.Game.ClipboardText=null;}});RefreshState();}
}
sealed class TraceWindow:Form {
 protected override bool ShowWithoutActivation=>true;
 protected override CreateParams CreateParams{get{var p=base.CreateParams;p.ExStyle|=0x80|0x08000000;return p;}}
 public TraceWindow(Paradise host){FormBorderStyle=FormBorderStyle.None;ShowInTaskbar=false;TopMost=true;ClientSize=new(115,34);BackColor=Art.Cream;var b=new Button{Text="👣 金色碎屑",Dock=DockStyle.Fill,FlatStyle=FlatStyle.Flat,BackColor=Art.Cream};Controls.Add(b);b.Click+=(s,e)=>{host.Action(()=>host.Game.LifeAction("explore",null,"",null));host.ShowLife();};}
}
sealed class AchievementPanel:ScrollableControl {
 public Life Life=new();public string Message="";
 public AchievementPanel(){DoubleBuffered=true;AutoScroll=true;AutoScrollMinSize=new(750,970);BackColor=Art.Cream;AccessibleName="成就卡册";}
 protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);var g=e.Graphics;g.TranslateTransform(AutoScrollPosition.X,AutoScrollPosition.Y);g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
 Art.Text(g,Message,10,8,12,Art.Ink,false,730);Art.Text(g,$"脚印：{(Life.TraceReady?"发现碎屑，可追踪":"等待新的痕迹")} · 安全窝：{(Life.SafeLeft?"开启":"关闭")} · 专注剩余 {(int)Life.FocusRemaining} 秒",10,48,12,Art.Ink,false,730);
 for(int i=0;i<Gala.Life.Achievements.Length;i++){var a=Gala.Life.Achievements[i];int x=i%2*375+5,y=i/2*79+83;bool earned=Life.Cards.TryGetValue(a.Id,out double date);Art.Round(g,new(x,y,365,69),earned?Color.FromArgb(221,230,205):Color.FromArgb(236,235,223),12);Art.Text(g,(earned?"✦ ":"○ ")+a.Name,x+12,y+10,14,Art.Ink,true,339);Art.Text(g,earned?DateTimeOffset.FromUnixTimeSeconds((long)date).ToLocalTime().ToString("g"):"尚未发现 · 不必集齐每条支线",x+12,y+39,11,Art.Ink,false,339);}}
}
