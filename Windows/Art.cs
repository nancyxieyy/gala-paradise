using System.Drawing.Drawing2D;
namespace Gala;

static class Art
{
    public static Color Ink = Color.FromArgb(49, 56, 43), Cream = Color.FromArgb(247, 243, 225), Moss =
        Color.FromArgb(69, 92, 59), Orange = Color.FromArgb(219, 99, 48);
    static Color Brown = Color.FromArgb(162, 101, 61);
    public static void Oval(Graphics g, Color c, float x, float y, float w, float h, Color? outline = null,
        float line = 2)
    {
        using var b = new SolidBrush(c);
        g.FillEllipse(b, x, y, w, h);
        if (outline.HasValue)
        {
            using var p = new Pen(outline.Value, line);
            g.DrawEllipse(p, x, y, w, h);
        }
    }
    public static void Line(Graphics g, Color c, float width, params PointF[] pts)
    {
        using var p = new Pen(c, width) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
        g.DrawLines(p, pts);
    }
    public static void Round(Graphics g, RectangleF r, Color c, float radius = 12)
    {
        using var path = new GraphicsPath();
        float d = radius * 2;
        path.AddArc(r.X, r.Y, d, d, 180, 90);
        path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        using var b = new SolidBrush(c);
        g.FillPath(b, path);
    }
    public static void Text(Graphics g, string s, float x, float y, float size = 14, Color? c = null, bool bold =
        false, float width = 850)
    {
        using var f = new Font("Microsoft YaHei UI", size, bold ? FontStyle.Bold : FontStyle.Regular,
            GraphicsUnit.Pixel);
        using var b = new SolidBrush(c ?? Ink);
        using var fmt = new StringFormat
        {
            Trimming = StringTrimming.EllipsisCharacter,
            FormatFlags =
            StringFormatFlags.NoWrap
        };
        g.DrawString(s, f, b, new RectangleF(x, y, width, size * 2), fmt);
    }
    public static void Bug(Graphics g, RectangleF box, Kind kind = Kind.Adult, double phase = 0, bool flying =
        false, float facing = 1, double eggProgress = 0, bool emptyShell = false,
        bool eggDormant = false, double residueProgress = 0)
    {
        if (kind is Kind.Mouse or Kind.CatPaw)
        {
            Friend(g, box, kind == Kind.CatPaw, phase, facing);
            return;
        }
        var state = g.Save();
        g.TranslateTransform(box.X, box.Y);
        g.ScaleTransform(box.Width / 140, box.Height / 140);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        if (kind == Kind.Stain)
        {
            for (int n = 0; n < 8; n++)
            {
                var a = n * .79;
                Oval(g, Color.FromArgb(225, 218, 184, 103), 60 + (float)Math.Cos(a) * 27,
                    65 + (float)Math.Sin(a) * 17, 19 + n % 3 * 7, 18);
            }
            Oval(g, Color.FromArgb(235, 201, 118), 36, 60, 65, 37);
            Oval(g, Color.FromArgb(255, 241, 185), 42, 65, 15, 7);
            Oval(g, Brown, 17, 61, 5, 4);
        }
        else if (kind == Kind.Egg)
        {
            float progress = (float)Math.Clamp(eggProgress, 0, 1);
            for (int n = 0; n < 3; n++)
            {
                float x = 29 + n * 23, y = 70 - n % 2 * 8;
                Oval(g, Color.FromArgb(emptyShell ? 140 : 255, 217, 183, 140), x, y + (emptyShell ? 18 : 0),
                    29 + progress * 3, emptyShell ? 15 : 37 + progress * 3, Color.FromArgb(140, 105, 72), 2.5f);
                if (progress < .65)
                {
                    for (int k = 0; k < 3; k++)
                        Line(g, Color.FromArgb(174, 137, 99), 1.5f, new(x + 7, y + 9 + k * 7), new(x + 21,
                            y + 9 + k * 7));
                }
                else if (emptyShell)
                    Line(g, Color.FromArgb(140, 140, 105, 72), 2, new(x + 3, y + 22), new(x + 8, y + 18),
                        new(x + 14, y + 23), new(x + 21, y + 18), new(x + 27, y + 22));
                else if (!eggDormant)
                    Line(g, Color.FromArgb(140, 105, 72), 2, new(x + 15, y + 3), new(x + 9, y + 13), new(x + 19,
                        y + 21), new(x + 12, y + 32));
            }
        }
        else
        {
            bool dead = kind == Kind.Corpse;
            if (dead)
            {
                g.TranslateTransform(140, 140);
                g.RotateTransform(180);
            }
            Oval(g, Color.FromArgb(40, 110, 76, 49), 27, 107, 95, 15);
            float wig = (float)Math.Sin(phase * 12) * 4;
            for (int n = 0; n < 3; n++)
            {
                float x = 37 + n * 29;
                Line(g, Color.FromArgb(85, 56, 33), 4, new(x, 91), new(x - 9, 111 + wig), new(x - 17, 114 + wig));
                Line(g, Color.FromArgb(85, 56, 33), 4, new(x + 10, 87), new(x + 24, 103 - wig), new(x + 29, 107 - wig));
            }
            if (flying)
            {
                Oval(g, Color.FromArgb(233, 243, 221), 0, 41, 73, 42 + wig, Ink);
                Oval(g, Color.FromArgb(233, 243, 221), 73, 35, 64, 49 - wig, Ink);
            }
            using var body = new GraphicsPath();
            body.AddBezier(24, 70, 37, 23, 86, 27, 117, 53);
            body.AddBezier(117, 53, 135, 66, 125, 87, 116, 104);
            body.AddBezier(116, 104, 94, 127, 49, 122, 32, 110);
            body.CloseFigure();
            double dry = Math.Clamp(residueProgress, 0, 1);
            var brown = dead ? Color.FromArgb((int)(162 + 23 * dry), (int)(101 + 69 * dry),
                (int)(61 + 79 * dry)) : Brown;
            using var bb = new SolidBrush(kind == Kind.Gold ? Color.FromArgb(233, 188, 62) : brown);
            using var pen = new Pen(Ink, 3.5f);
            g.FillPath(bb, body);
            g.DrawPath(pen, body);
            using var wing = new GraphicsPath();
            wing.AddBezier(78, 39, 101, 48, 112, 79, 106, 99);
            using var wp = new Pen(Color.FromArgb(118, 73, 47), 2.5f);
            g.DrawPath(wp, wing);
            Oval(g, kind == Kind.Gold ? Color.FromArgb(213, 165, 40) :
                (dead ? brown : Color.FromArgb(152, 91, 56)), 20, 64, 85, 53,
                Ink, 3.5f);
            for (int n = 0; n < 2; n++)
            {
                float x = n * 42 + 22;
                Oval(g, Color.White, x, 69, 43, 42, Ink, 3.2f);
                if (dead)
                {
                    Line(g, Ink, 3, new(x + 14, 82), new(x + 27, 96));
                    Line(g, Ink, 3, new(x + 27, 82), new(x + 14, 96));
                }
                else
                    Oval(g, Ink, x + 19 + facing * 5, 85, 8, 12);
            }
            using var ant = new GraphicsPath();
            ant.AddBezier(42, 71, 31, 44, 29, 26, 35 + wig, 9);
            ant.StartFigure();
            ant.AddBezier(68, 68, 71, 48, 76, 27, 87 + wig, 14);
            using var ap = new Pen(Ink, 3) { StartCap = LineCap.Round, EndCap = LineCap.Round };
            g.DrawPath(ap, ant);
            Oval(g, Color.FromArgb(201, 145, 103), 99, 51, 8, 5);
            Line(g, Ink, 2, new(56, 114), new(64, 115), new(70, 112));
        }
        g.Restore(state);
    }
    public static void Cue(Graphics g, CueSnapshot cue)
    {
        if (cue.Shell)
        {
            Bug(g, new(34, 0, 52, 52), Kind.Egg, eggProgress: 1, emptyShell: true);
            return;
        }
        for (int n = 0; n < 7 && cue.Chemical > 0; n++)
            Oval(g, Color.FromArgb((int)(cue.Chemical * 92), 228, 239, 217), 12 + n * 13, 18 + n % 3 * 7, 20, 8,
                Color.FromArgb((int)(cue.Chemical * 51), 166, 186, 153), 1);
        for (int n = 0; n < (int)(cue.Crumbs * 8); n++)
            Oval(g, Color.FromArgb(140, 167, 129, 76), 19 + n * 11, 38 + n % 3 * 4, 3 + n % 2, 2);
    }
    public static void Friend(Graphics g, RectangleF box, bool cat, double phase, float facing = 1)
    {
        var save = g.Save();
        g.TranslateTransform(box.X, box.Y);
        g.ScaleTransform(box.Width / 140, box.Height / 140);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        if (!cat && facing > 0)
        {
            g.TranslateTransform(140, 0);
            g.ScaleTransform(-1, 1);
        }
        if (cat)
        {
            float contact = (float)Rules.PawContact(phase);
            g.TranslateTransform((1 - contact) * 130, -(1 - contact) * 9);
            Oval(g, Color.FromArgb((int)(20 + contact * 41), 102, 83, 59), 16, 88, 119, 26);
            using var paw = new GraphicsPath();
            paw.AddLine(145, 43, 78, 43);
            paw.AddBezier(78, 43, 65, 29, 47, 29, 41, 39);
            paw.AddBezier(41, 39, 25, 37, 17, 46, 23, 57);
            paw.AddBezier(23, 57, 8, 58, 7, 73, 19, 78);
            paw.AddBezier(19, 78, 10, 90, 24, 103, 37, 98);
            paw.AddBezier(37, 98, 46, 112, 63, 111, 78, 102);
            paw.AddLine(78, 102, 145, 102);
            paw.CloseFigure();
            using var furBrush = new SolidBrush(Color.FromArgb(235, 193, 141));
            using var pawPen = new Pen(Ink, 3);
            g.FillPath(furBrush, paw);
            g.DrawPath(pawPen, paw);
            Oval(g, Color.FromArgb(245, 215, 174), 43, 44, 37, 17);
            var crease = Color.FromArgb(156, 114, 76);
            Line(g, crease, 2, new(23, 57), new(37, 61));
            Line(g, crease, 2, new(19, 78), new(35, 78));
            Line(g, crease, 2, new(37, 98), new(43, 89));
            foreach (float x in new[] { 99f, 116f })
                Line(g, Color.FromArgb(198, 149, 101), 4, new(x, 45), new(x - 7, 58));
        }
        else
        {
            float wig = (float)Math.Sin(phase * 12) * 3;
            using var tail = new GraphicsPath();
            tail.AddBezier(99, 100, 132, 126, 137, 103, 134, 70 + wig);
            using var outline = new Pen(Ink, 7);
            using var pink = new Pen(Color.FromArgb(220, 163, 160), 4);
            g.DrawPath(outline, tail);
            g.DrawPath(pink, tail);
            Oval(g, Color.FromArgb(40, 118, 88, 69), 18, 112, 94, 12);
            foreach (float x in new[] { 36f, 87f })
                Oval(g, Color.FromArgb(220, 163, 160), x + wig, 108, 19, 11, Ink, 3);
            var fur = Color.FromArgb(169, 151, 140);
            var blush = Color.FromArgb(220, 163, 160);
            Oval(g, fur, 23, 38, 27, 30, Ink, 3.5f);
            Oval(g, blush, 29, 44, 15, 18);
            Oval(g, fur, 23, 51, 91, 65, Ink, 4);
            Oval(g, Color.FromArgb(198, 183, 166), 25, 75, 69, 38);
            // Open base joins the near ear to the head instead of making a separate ring.
            using var ear = new GraphicsPath();
            ear.AddBezier(54, 69, 48, 65, 46, 55, 50, 48);
            ear.AddBezier(50, 48, 54, 33, 74, 32, 81, 43);
            ear.AddBezier(81, 43, 91, 56, 86, 68, 75, 72);
            using var earFill = new SolidBrush(fur);
            using var earPen = new Pen(Ink, 3.5f) { StartCap = LineCap.Round, EndCap = LineCap.Round };
            g.FillPath(earFill, ear);
            g.DrawPath(earPen, ear);
            Oval(g, Color.FromArgb(230, 180, 174), 56, 43, 23, 23);
            Oval(g, Color.FromArgb(211, 195, 180), 87, 62, 13, 7);
            Oval(g, Color.FromArgb(211, 195, 180), 100, 72, 5, 5);
            Oval(g, Color.White, 9, 67, 33, 37, Ink, 3.5f);
            Oval(g, Color.White, 37, 64, 43, 42, Ink, 3.5f);
            Oval(g, Ink, 16, 80, 8, 12);
            Oval(g, Ink, 47, 79, 9, 13);
            Oval(g, Color.FromArgb(214, 143, 150), 6, 98, 14, 10, Ink, 2.5f);
            Line(g, Ink, 1.5f, new(16, 109), new(20, 112));
            for (int n = 0; n < 3; n++)
                Line(g, Color.FromArgb(107, 98, 86), .9f, new(25, 109 + n * 2), new(44, 108 + n * 7));
        }
        g.Restore(save);
    }
    public static void Effect(Graphics g, Tool tool, double elapsed, bool playful = false)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        if (tool == Tool.Poison)
        {
            if (elapsed < .65)
            {
                Round(g, new(68, 28, 22, 47), Color.FromArgb(168, 195, 160), 6);
                Round(g, new(63, 21, 23, 8), Ink, 2);
                Oval(g, Color.FromArgb(237, 197, 166), 79, 49, 23, 17, Ink);
                Line(g, Color.FromArgb(237, 197, 166), 13, new(98, 59), new(110, 83));
                for (int i = 0; i < 5; i++)
                    Line(g, Color.FromArgb(191, 217, 218), 1.5f, new(63, 25), new(20, 18 + i * 9));
                Text(g, "呲——", 4, 0, 13, Moss, true);
            }
            for (int i = 0; i < 9; i++)
                Oval(g, Color.FromArgb(232, 243, 232), 8 + i % 4 * 13, 60 + i / 4 * 10, 17, 16, Color.FromArgb(190,
                    213, 190), 1);
        }
        else if (tool == Tool.Slipper)
        {
            if (!playful)
                Text(g, "啪！", 15, 4, 18, Orange, true);
            Oval(g, Color.FromArgb(233, 175, 109), 60, 24, 22, 52, Ink);
            Line(g, Moss, 3, new(63, 51), new(71, 39), new(79, 53));
        }
        else
        {
            if (!playful)
                Text(g, tool == Tool.Vacuum ? "咻——" : tool == Tool.Cleaner ? "亮晶晶 ✧" : "噗叽！", 8, 20, 16, Moss, true);
            for (int n = 0; n < 4; n++)
                Line(g, Moss, 2, new(25, 50 + n * 9), new(75, 45 + n * 6));
        }
    }
}
