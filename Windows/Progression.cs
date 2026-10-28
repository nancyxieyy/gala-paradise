namespace Gala;

public class Progression
{
    public int Shells
    {
        get; set;
    }
    public List<Tool> Owned { get; set; } = [Tool.Pinch];
    public double Played
    {
        get; set;
    }
    public List<string> Seen { get; set; } = [];
}
