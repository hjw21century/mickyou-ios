using Microsoft.UI.Xaml;
namespace PocketSpeaker;
public partial class App : Application {
    private Window? window;
    public App() { InitializeComponent(); RequestedTheme = ApplicationTheme.Dark; }
    protected override void OnLaunched(LaunchActivatedEventArgs args) { window = new MainWindow(); window.Activate(); }
}
