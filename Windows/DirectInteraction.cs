namespace Gala;
sealed class ReactionWindow:Form {
 readonly string text;readonly System.Windows.Forms.Timer timer=new(){Interval=1800};
 protected override bool ShowWithoutActivation=>true;
 protected override CreateParams CreateParams{get{var p=base.CreateParams;p.ExStyle|=0x20|0x80|0x08000000;return p;}}
 public ReactionWindow(string text){this.text=text;FormBorderStyle=FormBorderStyle.None;ShowInTaskbar=false;TopMost=true;ClientSize=new(250,48);BackColor=Art.Cream;DoubleBuffered=true;timer.Tick+=(s,e)=>Close();timer.Start();}
 protected override void OnPaint(PaintEventArgs e){base.OnPaint(e);Art.Text(e.Graphics,text,12,12,12,Art.Ink,false,226);}
 protected override void OnFormClosed(FormClosedEventArgs e){timer.Dispose();base.OnFormClosed(e);}
}
sealed partial class Paradise {
 readonly Dictionary<Guid,ReactionWindow> reactions=[];
 void React(Resident r,string text){if(smoke)return;if(reactions.Remove(r.Id,out var old))old.Close();var screen=Screen.FromPoint(new((int)r.X+50,(int)r.Y+50)).WorkingArea;var p=new ReactionWindow(text);p.Location=new(Math.Clamp((int)r.X+(Rules.Canvas(r.Kind)-250)/2,screen.Left+4,screen.Right-254),Math.Clamp((int)r.Y-45,screen.Top+4,screen.Bottom-52));reactions[r.Id]=p;p.FormClosed+=(s,e)=>{if(reactions.TryGetValue(r.Id,out var current)&&current==p)reactions.Remove(r.Id);};p.Show();}
 public static string? Ask(string title,string hint,string initial=""){
  using var form=new Form{Text=title,ClientSize=new(360,150),StartPosition=FormStartPosition.CenterScreen,FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false,MinimizeBox=false,BackColor=Art.Cream};
  var label=new Label{Text=hint,Bounds=new(16,15,328,30)};var field=new TextBox{Text=initial,Bounds=new(16,51,328,26)};var ok=new Button{Text="确定",DialogResult=DialogResult.OK,Bounds=new(180,99,78,30)};var cancel=new Button{Text="取消",DialogResult=DialogResult.Cancel,Bounds=new(266,99,78,30)};form.Controls.AddRange([label,field,ok,cancel]);form.AcceptButton=ok;form.CancelButton=cancel;form.Shown+=(s,e)=>field.Focus();return form.ShowDialog()==DialogResult.OK?field.Text:null;
 }
 void AnimalMenu(Guid id){
  var r=Game.State.Residents.Find(r=>r.Id==id);if(r==null||Game.Paused||Game.State.Life.FocusRemaining>0)return;if(!r.Live){Use(id);return;}r.HoldUntil=Now+60;
  var menu=new ContextMenuStrip();Game.State.Life.Bonds.TryGetValue(id.ToString(),out var b);menu.Items.Add($"{(b?.Name.Length>0?b.Name:r.Kind==Kind.Mouse?"小老鼠":r.Kind==Kind.CatPaw?"猫咪":"小旮杂")}").Enabled=false;
  void Add(string title,string action){menu.Items.Add(title,null,(s,e)=>{
   if(action=="leave"){Game.Blind?.Action("leave",id.ToString(),time:Game.State.World?.time??0);r.HoldUntil=0;r.ExitAt=Now;React(r,"好啦，去玩吧～");return;}
   string text="";if(action=="name"){var name=Ask("给它起个名字","它会记住这个名字。",b?.Name??"");if(name==null)return;text=name;}
   Action(()=>Game.LifeAction(action,id,text,null,inPlace:true));r.ReactionUntil=Now+.55;r.HoldUntil=Now+1.5;string msg=Game.Message;if((action=="pet"||action=="feed")&&msg.Contains("稍等"))msg=action=="pet"?"还想被摸摸 ♡":"还在嚼呢，嚼嚼嚼～";React(r,msg);
  });}
  Add("♡ 摸一摸","pet");Add("喂一口","feed");Add("起个名字…","name");Add(b?.Partner==true?"已经是我的伙伴 ♡":"成为我的伙伴","bond");if(r.Kind==Kind.Gold)Add("收下黄金卵壳","gold");if(r.Friend&&b?.Partner==true)Add("去右边巡逻","patrol");menu.Items.Add(new ToolStripSeparator());Add("放它去玩","leave");menu.Closed+=(s,e)=>{r.HoldUntil=Now+1.5;dashboard.BeginInvoke(new Action(menu.Dispose));};menu.Show(Cursor.Position);
 }
}
