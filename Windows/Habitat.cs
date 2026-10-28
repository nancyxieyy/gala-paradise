using System.Security.Cryptography;
using System.Text;
using System.Drawing;
namespace Gala;

public class FolderHistory
{
    public double Visits
    {
        get; set;
    }
    public double LastSeen
    {
        get; set;
    }
}
public class Habitat
{
    public double Rate { get; set; } = 1;
    public double CleanUntil
    {
        get; set;
    }
    public Dictionary<string, FolderHistory> Folders { get; set; } = [];
    public void Clean(double now)
    {
        CleanUntil = now + 300;
        foreach (var h in Folders.Values)
        {
            h.Visits = Math.Max(6, h.Visits);
            h.LastSeen = now;
        }
    }
    public static PointF Border(Rectangle f, int side, double fraction)
    {
        float t = (float)Math.Clamp(fraction, .1, .9);
        return side switch
        {
            0 => new(f.Left - 55, f.Top + f.Height * t - 85),
            1 => new(f.Right - 55, f.Top + f.Height * t - 85),
            2 => new(f.Left + f.Width * t - 55, f.Top - 85),
            _ => new(f.Left + f.Width * t - 55, f.Bottom - 85)
        };
    }
}
