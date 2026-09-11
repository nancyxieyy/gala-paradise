namespace Gala;
sealed class LifeWindow:Form {
 readonly Paradise host;readonly ComboBox guests=new(){DropDownStyle=ComboBoxStyle.DropDownList};readonly ComboBox notes=new(){DropDownStyle=ComboBoxStyle.DropDownList};readonly TextBox input=new();readonly NumericUpDown minutes=new(){Minimum=1,Maximum=120,Value=25};readonly AchievementPanel report=new();
 readonly CompanionPicture portrait=new();readonly Label focusStatus=new();readonly Label feedback=new();
 List<Guid> ids=[];List<string> noteIds=[];
 public LifeWindow(Paradise host){this.host=host;Text="我的小窝";ClientSize=new(620,450);BackColor=Art.Cream;StartPosition=FormStartPosition.CenterScreen;AutoScaleMode=AutoScaleMode.Dpi;Font=new Font("Microsoft YaHei UI",10);FormBorderStyle=FormBorderStyle.FixedSingle;MaximizeBox=false;
  var panes=Enumerable.Range(0,4).Select(_=>new Panel{Bounds=new(24,76,572,330),BackColor=Art.Cream}).ToArray();foreach(var p in panes)Controls.Add(p);
  string[] names=["伙伴","纸条","专注","成就"];for(int i=0;i<4;i++){int tab=i;var b=new Button{Text=names[i],Bounds=new(24+i*143,22,141,32),FlatStyle=FlatStyle.Flat,BackColor=Color.FromArgb(235,236,221)};b.Click+=(s,e)=>{for(int n=0;n<4;n++)panes[n].Visible=n==tab;};Controls.Add(b);panes[i].Visible=i==0;}
  void Title(string text,int y,int pane,int x=0){panes[pane].Controls.Add(new Label{Text=text,Bounds=new(x,y,560-x,30),Font=new Font("Microsoft YaHei UI",12,FontStyle.Bold)});}
  void Place(Control c,int x,int y,int w,int h,int pane){c.Bounds=new(x,y,w,h);panes[pane].Controls.Add(c);}
  void Button(string text,int x,int y,int w,int pane,string action){var b=new Button{Text=text,FlatStyle=FlatStyle.Flat,BackColor=Color.FromArgb(235,236,221)};Place(b,x,y,w,38,pane);b.Click+=(s,e)=>Run(action);}
  Title("熟悉的身影",0,0);Place(guests,0,42,360,30,0);Place(portrait,382,30,165,165,0);guests.SelectedIndexChanged+=(s,e)=>{if(guests.SelectedIndex>=0&&guests.SelectedIndex<ids.Count){portrait.Kind=host.Game.State.Residents.Find(r=>r.Id==ids[guests.SelectedIndex])?.Kind??Kind.Adult;portrait.Invalidate();}};Title("叫它出来，在身上右键交朋友。",94,0);Button("出来玩",0,137,144,0,"recall");Button("分享这位朋友",154,137,176,0,"share");Title("给大家留个位置",220,0);Button("开关安全窝",0,264,172,0,"safe");Button("安排共居",182,264,172,0,"coexist");Button("接朋友入住…",364,264,184,0,"import");
  Title("交给它，替你收着。",0,1);Place(input,0,42,572,32,1);input.PlaceholderText="写一条待办，或粘贴一个链接";Button("收好",0,88,112,1,"stash");Place(notes,0,151,572,30,1);Button("取回",0,198,120,1,"return");Button("完成 / 撤销",130,198,160,1,"done");Button("删除",300,198,110,1,"delete");Title("取回只会复制，纸条仍留在这里。",268,1);
  Title("一起安静一会儿。",26,2);Place(minutes,0,88,80,34,2);Title("分钟",94,2,96);Button("开始专注",0,151,180,2,"focus");Button("结束计时",192,151,160,2,"cancel");Place(focusStatus,0,223,560,55,2);Place(report,0,0,572,330,3);feedback.Bounds=new(24,418,572,24);feedback.ForeColor=Art.Moss;Controls.Add(feedback);RefreshState();
 }
 public void RefreshState(){var g=host.Game;var l=g.State.Life;Guid? old=guests.SelectedIndex>=0?ids[guests.SelectedIndex]:null;ids=g.State.Residents.Where(r=>r.Live&&(l.Bonds.ContainsKey(r.Id.ToString())||!r.Hidden)).Select(r=>r.Id).ToList();guests.Items.Clear();foreach(var id in ids){var r=g.State.Residents.Find(r=>r.Id==id)!;l.Bonds.TryGetValue(id.ToString(),out var b);guests.Items.Add($"{(b?.Name.Length>0?b.Name:r.Kind==Kind.Mouse?"小老鼠":r.Kind==Kind.CatPaw?"猫咪":"旮杂")} {(b?.Partner==true?"· 我的伙伴":"")}");}if(ids.Count>0)guests.SelectedIndex=old.HasValue&&ids.Contains(old.Value)?ids.IndexOf(old.Value):0;int ni=notes.SelectedIndex;noteIds=l.Notes.Select(n=>n.Id).ToList();notes.Items.Clear();foreach(var n in l.Notes)notes.Items.Add((n.Done?"✓ ":"○ ")+n.Text[..Math.Min(45,n.Text.Length)].Replace('\n',' '));if(noteIds.Count>0)notes.SelectedIndex=Math.Clamp(ni,0,noteIds.Count-1);
  feedback.Text=g.Message;
  focusStatus.Text=l.FocusRemaining>0?$"还剩 {(int)Math.Ceiling(l.FocusRemaining/60)} 分钟 · 大家都在休息":"计时期间，不会有小动物突然跑出来。";
  report.Life=l;report.Message=g.Message;report.Invalidate();report.AccessibleDescription=g.Message+Environment.NewLine+$"\r\n脚印：{(l.TraceReady?"发现碎屑，点探索追踪":"等待住客留下痕迹")} · 安全窝：{(l.SafeLeft?"开启":"关闭")} · 专注剩余：{(int)l.FocusRemaining} 秒\r\n\r\n"+string.Join("\r\n",Life.Achievements.Select(a=>l.Cards.TryGetValue(a.Id,out var date)?$"✓ {a.Name} · {DateTimeOffset.FromUnixTimeSeconds((long)date).ToLocalTime():g}":"○ "+a.Name));
 }
 void Run(string action){if(action=="import"){var code=Paradise.Ask("接朋友入住","粘贴朋友发来的领养码。");if(code!=null)host.Action(()=>host.Game.LifeAction("adopt",null,code,null));RefreshState();return;}if(action!="refresh")host.Action(()=>{host.Game.LifeAction(action,guests.SelectedIndex>=0?ids[guests.SelectedIndex]:null,input.Text,notes.SelectedIndex>=0?noteIds[notes.SelectedIndex]:null,(double)minutes.Value);if(host.Game.ClipboardText is string text){try{Clipboard.SetText(text);}catch(System.Runtime.InteropServices.ExternalException){host.Game.Message="剪贴板忙，请重试复制";}host.Game.ClipboardText=null;}});RefreshState();}
}
sealed class TraceWindow:Form {
 protected override bool ShowWithoutActivation=>true;
 protected override CreateParams CreateParams{get{var p=base.CreateParams;p.ExStyle|=0x80|0x08000000;return p;}}
 public TraceWindow(Paradise host){FormBorderStyle=FormBorderStyle.None;ShowInTaskbar=false;TopMost=true;ClientSize=new(115,34);BackColor=Art.Cream;var b=new Button{Text="👣 细小碎屑",Dock=DockStyle.Fill,FlatStyle=FlatStyle.Flat,BackColor=Art.Cream};Controls.Add(b);b.Click+=(s,e)=>{host.Action(()=>host.Game.LifeAction("explore",null,"",null));host.ShowLife();};}
}
sealed class AchievementPanel:ScrollableControl {
 public Life Life=new();public string Message="";
 public AchievementPanel(){DoubleBuffered=true;AutoScroll=true;AutoScrollMinSize=new(550,970);BackColor=Art.Cream;AccessibleName="成就卡册";}
 protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);var g=e.Graphics;g.TranslateTransform(AutoScrollPosition.X,AutoScrollPosition.Y);g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
 Art.Text(g,Message,10,8,12,Art.Ink,false,ClientSize.Width-20);Art.Text(g,$"脚印：{(Life.TraceReady?"发现碎屑，可追踪":"等待新的痕迹")} · 安全窝：{(Life.SafeLeft?"开启":"关闭")} · 专注剩余 {(int)Life.FocusRemaining} 秒",10,48,12,Art.Ink,false,ClientSize.Width-20);
 for(int i=0;i<Gala.Life.Achievements.Length;i++){var a=Gala.Life.Achievements[i];int column=ClientSize.Width/2;int x=i%2*column+5,y=i/2*79+83;bool earned=Life.Cards.TryGetValue(a.Id,out double date);Art.Round(g,new(x,y,column-10,69),earned?Color.FromArgb(221,230,205):Color.FromArgb(236,235,223),12);Art.Text(g,(earned?"✦ ":"○ ")+a.Name,x+12,y+10,14,Art.Ink,true,column-34);Art.Text(g,earned?DateTimeOffset.FromUnixTimeSeconds((long)date).ToLocalTime().ToString("g"):"尚未发现 · 不必集齐每条支线",x+12,y+39,11,Art.Ink,false,column-34);}}
}

sealed class CompanionPicture:Control {
 public Kind Kind=Kind.Adult;
 public CompanionPicture(){DoubleBuffered=true;BackColor=Art.Cream;}
 protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);Art.Bug(e.Graphics,new(5,5,Width-10,Height-10),Kind,Kind==Kind.CatPaw?3:0);}
}
