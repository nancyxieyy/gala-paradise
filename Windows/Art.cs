using System.Drawing.Drawing2D;
namespace Gala;
static class Art {
    public static Color Ink=Color.FromArgb(49,56,43),Cream=Color.FromArgb(247,243,225),Moss=Color.FromArgb(69,92,59),Orange=Color.FromArgb(219,99,48);
    static Color Brown=Color.FromArgb(162,101,61);
    public static void Oval(Graphics g,Color c,float x,float y,float w,float h,Color? outline=null,float line=2){using var b=new SolidBrush(c);g.FillEllipse(b,x,y,w,h);if(outline.HasValue){using var p=new Pen(outline.Value,line);g.DrawEllipse(p,x,y,w,h);}}
    public static void Line(Graphics g,Color c,float width,params PointF[] pts){using var p=new Pen(c,width){StartCap=LineCap.Round,EndCap=LineCap.Round,LineJoin=LineJoin.Round};g.DrawLines(p,pts);}
    public static void Round(Graphics g,RectangleF r,Color c,float radius=12){using var path=new GraphicsPath();float d=radius*2;path.AddArc(r.X,r.Y,d,d,180,90);path.AddArc(r.Right-d,r.Y,d,d,270,90);path.AddArc(r.Right-d,r.Bottom-d,d,d,0,90);path.AddArc(r.X,r.Bottom-d,d,d,90,90);path.CloseFigure();using var b=new SolidBrush(c);g.FillPath(b,path);}
    public static void Text(Graphics g,string s,float x,float y,float size=14,Color? c=null,bool bold=false,float width=850){using var f=new Font("Microsoft YaHei UI",size,bold?FontStyle.Bold:FontStyle.Regular,GraphicsUnit.Pixel);using var b=new SolidBrush(c??Ink);using var fmt=new StringFormat{Trimming=StringTrimming.EllipsisCharacter,FormatFlags=StringFormatFlags.NoWrap};g.DrawString(s,f,b,new RectangleF(x,y,width,size*2),fmt);}
    public static void Bug(Graphics g,RectangleF box,Kind kind=Kind.Adult,double phase=0,bool flying=false,float facing=1){
        var state=g.Save();g.TranslateTransform(box.X,box.Y);g.ScaleTransform(box.Width/140,box.Height/140);g.SmoothingMode=SmoothingMode.AntiAlias;
        if(kind==Kind.Stain){for(int n=0;n<8;n++){var a=n*.79;Oval(g,Color.FromArgb(225,218,184,103),60+(float)Math.Cos(a)*27,65+(float)Math.Sin(a)*17,19+n%3*7,18);}Oval(g,Color.FromArgb(235,201,118),36,60,65,37);Oval(g,Color.FromArgb(255,241,185),42,65,15,7);Oval(g,Brown,17,61,5,4);}
        else if(kind==Kind.Egg){for(int n=0;n<3;n++){Oval(g,Color.FromArgb(217,183,140),29+n*23,70-n%2*8,29,37,Color.FromArgb(140,105,72),2.5f);for(int k=0;k<3;k++)Line(g,Color.FromArgb(174,137,99),1.5f,new(36+n*23,79+k*7-n%2*8),new(50+n*23,79+k*7-n%2*8));}}
        else{
            bool dead=kind==Kind.Corpse;if(dead){g.TranslateTransform(140,140);g.RotateTransform(180);}
            Oval(g,Color.FromArgb(40,110,76,49),27,107,95,15);float wig=(float)Math.Sin(phase*12)*4;
            for(int n=0;n<3;n++){float x=37+n*29;Line(g,Color.FromArgb(85,56,33),4,new(x,91),new(x-9,111+wig),new(x-17,114+wig));Line(g,Color.FromArgb(85,56,33),4,new(x+10,87),new(x+24,103-wig),new(x+29,107-wig));}
            if(flying){Oval(g,Color.FromArgb(233,243,221),0,41,73,42+wig,Ink);Oval(g,Color.FromArgb(233,243,221),73,35,64,49-wig,Ink);}
            using var body=new GraphicsPath();body.AddBezier(24,70,37,23,86,27,117,53);body.AddBezier(117,53,135,66,125,87,116,104);body.AddBezier(116,104,94,127,49,122,32,110);body.CloseFigure();using var bb=new SolidBrush(Brown);using var pen=new Pen(Ink,3.5f);g.FillPath(bb,body);g.DrawPath(pen,body);
            using var wing=new GraphicsPath();wing.AddBezier(78,39,101,48,112,79,106,99);using var wp=new Pen(Color.FromArgb(118,73,47),2.5f);g.DrawPath(wp,wing);
            Oval(g,Color.FromArgb(152,91,56),20,64,85,53,Ink,3.5f);
            for(int n=0;n<2;n++){float x=n*42+22;Oval(g,Color.White,x,69,43,42,Ink,3.2f);if(dead){Line(g,Ink,3,new(x+14,82),new(x+27,96));Line(g,Ink,3,new(x+27,82),new(x+14,96));}else Oval(g,Ink,x+19+facing*5,85,8,12);}
            using var ant=new GraphicsPath();ant.AddBezier(42,71,31,44,29,26,35+wig,9);ant.StartFigure();ant.AddBezier(68,68,71,48,76,27,87+wig,14);using var ap=new Pen(Ink,3){StartCap=LineCap.Round,EndCap=LineCap.Round};g.DrawPath(ap,ant);
            Oval(g,Color.FromArgb(201,145,103),99,51,8,5);Line(g,Ink,2,new(56,114),new(64,115),new(70,112));
        }
        g.Restore(state);
    }
}
