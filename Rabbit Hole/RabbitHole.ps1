param([switch]$SelfTest, [switch]$OnlineTest)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:background = $false
$script:intervalMinutes = 15
$script:question = $null
$script:answered = $false
$script:networkProcess = $null
$script:pending = $null
$script:lastRequest = [datetime]::MinValue
$script:ownsMutex = $false
$script:mutex = $null
$script:closing = $false
$script:popupState = 'closed'
$script:answerButtons = @()
$script:gamePath = Join-Path $PSScriptRoot 'game.html'

function Read-Window([string]$Markup) {
    [Windows.Markup.XamlReader]::Parse($Markup)
}
$script:menu = Read-Window @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="Rabbit Hole" Width="490" Height="495" WindowStartupLocation="CenterScreen" ResizeMode="NoResize" Background="#11130F" Foreground="#F4F1E7" FontFamily="Segoe UI">
 <Window.Resources><Style TargetType="Button"><Setter Property="Margin" Value="0,6,0,6"/><Setter Property="Padding" Value="15"/><Setter Property="FontSize" Value="16"/><Setter Property="Background" Value="#D6FA83"/><Setter Property="Foreground" Value="#17200C"/></Style></Window.Resources>
 <StackPanel Margin="30"><TextBlock Text="rabbit hole" FontSize="32" FontWeight="Bold" Foreground="#D6FA83"/><TextBlock Text="A little curiosity break." Margin="0,5,0,25" Foreground="#A9AF9C"/>
 <Button Name="Play" Content="Play now"/><TextBlock Text="Open a ten-question round in your browser." Foreground="#A9AF9C" Margin="0,0,0,15"/>
 <Button Name="Background" Content="Play from background"/><TextBlock Text="Close this window and get a small trivia prompt near your taskbar. Click it to pick a topic and answer." TextWrapping="Wrap" Foreground="#A9AF9C"/>
 <StackPanel Orientation="Horizontal" Margin="0,20,0,10"><TextBlock Text="Remind me every " VerticalAlignment="Center"/><ComboBox Name="Interval" Width="120" SelectedIndex="1"><ComboBoxItem Content="5 minutes" Tag="5"/><ComboBoxItem Content="15 minutes" Tag="15"/><ComboBoxItem Content="30 minutes" Tag="30"/><ComboBoxItem Content="60 minutes" Tag="60"/></ComboBox></StackPanel>
 <TextBlock Text="Tray menu: question now, pause, or quit.&#10;Internet required. Questions are never saved." Foreground="#A9AF9C" FontSize="12" Margin="0,10,0,0"/>
 </StackPanel>
</Window>
'@
$script:popup = Read-Window @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="Rabbit Hole trivia" Width="390" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" ShowInTaskbar="False" ShowActivated="False" Topmost="True" FontFamily="Segoe UI" Foreground="#F4F1E7">
 <Border Background="#1C2018" BorderBrush="#657548" BorderThickness="1" CornerRadius="14" Padding="18">
  <StackPanel><DockPanel><Button Name="Dismiss" DockPanel.Dock="Right" Content="x" Width="28" Height="26" Background="#303829" Foreground="#F4F1E7" ToolTip="Dismiss until the next reminder"/><TextBlock Text="rabbit hole" FontWeight="Bold" FontSize="18" Foreground="#D6FA83"/></DockPanel>
  <Button Name="Teaser" Margin="0,10,0,0" Padding="10" Background="#D6FA83" Foreground="#17200C" Content="Got a minute? Follow a rabbit hole."/>
  <ScrollViewer Name="QuestionScroll" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" MaxHeight="620"><StackPanel Name="Expanded" Visibility="Collapsed" Margin="0,12,0,0">
   <TextBlock Name="Prompt" Text="Pick your rabbit hole." TextWrapping="Wrap" FontSize="18" Margin="0,0,0,12"/>
   <WrapPanel Name="Categories"/>
   <TextBlock Name="Status" TextWrapping="Wrap" Foreground="#A9AF9C" Margin="0,8,0,5"/>
   <StackPanel Name="Answers"/>
   <TextBlock Name="Feedback" TextWrapping="Wrap" Foreground="#D6FA83" FontSize="16" Margin="0,10,0,5"/>
   <TextBlock Name="Credits" Text="Questions: Open Trivia DB - CC BY-SA 4.0" Foreground="#A9AF9C" FontSize="10" Margin="0,6,0,0"/>
  </StackPanel></ScrollViewer>
  </StackPanel>
 </Border>
</Window>
'@
$script:tray = New-Object System.Windows.Forms.NotifyIcon
$script:tray.Icon = [Drawing.SystemIcons]::Information
$script:tray.Text = 'Rabbit Hole - background trivia'
$script:trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
$script:nowItem = $trayMenu.Items.Add('Question now')
$script:pauseItem = $trayMenu.Items.Add('Pause reminders')
$script:playItem = $trayMenu.Items.Add('Play a full round')
$script:quitItem = $trayMenu.Items.Add('Quit Rabbit Hole')
$tray.ContextMenuStrip = $trayMenu
$script:reminder = New-Object Windows.Threading.DispatcherTimer
$script:expiry = New-Object Windows.Threading.DispatcherTimer
$script:fade = New-Object Windows.Threading.DispatcherTimer
$script:poll = New-Object Windows.Threading.DispatcherTimer
$poll.Interval = [timespan]::FromMilliseconds(150)
$fade.Interval = [timespan]::FromMilliseconds(40)
$script:paused = $false

function Position-Popup {
    # WPF work area is in device-independent pixels and excludes the taskbar.
    $area = [Windows.SystemParameters]::WorkArea
    $popup.MaxHeight = [math]::Max(180, $area.Height - 24)
    $popup.FindName('QuestionScroll').MaxHeight = [math]::Max(100, $area.Height - 110)
    $popup.Left = $area.Right - $popup.Width - 16
    $popup.Top = [math]::Max($area.Top + 12, $area.Bottom - $popup.ActualHeight - 16)
}
function Cancel-Request {
    $poll.Stop()
    if ($script:networkProcess) {
        if (-not $script:networkProcess.HasExited) { $script:networkProcess.Kill() }
        $script:networkProcess.Dispose()
    }
    $script:networkProcess = $null
    $script:pending = $null
    $script:networkError = $null
}
function Schedule-Next {
    $reminder.Stop()
    if ($script:background -and -not $script:paused) {
        $reminder.Interval = [timespan]::FromMinutes($script:intervalMinutes)
        $reminder.Start()
    }
}
function Dismiss-Popup {
    $expiry.Stop(); $fade.Stop(); Cancel-Request
    $popup.Hide(); $popup.Opacity = 1
    $script:question = $null; $script:answerButtons = @()
    $popup.FindName('Answers').Children.Clear()
    $popup.FindName('Prompt').Text = 'Pick your rabbit hole.'
    $popup.FindName('Feedback').Text = ''
    $script:popupState = 'closed'
    Schedule-Next
}
function Begin-Fade {
    $expiry.Stop()
    $fade.Start()
}
function Show-Reminder {
    if (-not $script:background) { return }
    Cancel-Request; $reminder.Stop(); $expiry.Stop(); $fade.Stop()
    $script:question = $null; $script:answered = $false
    $script:popupState = 'teaser'
    $popup.Opacity = 1
    $popup.FindName('Teaser').Visibility = 'Visible'
    $popup.FindName('Expanded').Visibility = 'Collapsed'
    $popup.FindName('Answers').Children.Clear()
    $popup.FindName('Feedback').Text = ''
    $popup.Show(); $popup.UpdateLayout(); Position-Popup
    # An ignored prompt quietly disappears. No missed-reminder backlog.
    $expiry.Interval = [timespan]::FromSeconds(45); $expiry.Start()
}
function Expand-Popup {
    $expiry.Stop(); $fade.Stop(); $popup.Opacity = 1
    $script:popupState = 'category'
    $popup.FindName('Teaser').Visibility = 'Collapsed'
    $popup.FindName('Expanded').Visibility = 'Visible'
    $popup.FindName('Categories').Visibility = 'Visible'
    $popup.FindName('Categories').IsEnabled = $true
    $popup.FindName('Prompt').Text = 'Pick your rabbit hole.'
    $popup.FindName('Status').Text = 'One question. No timer. Just curiosity.'
    $popup.FindName('Feedback').Text = ''
    $popup.UpdateLayout(); Position-Popup
    $null = $popup.Activate()
    # Avoid leaving an abandoned expanded panel on screen indefinitely.
    $expiry.Interval = [timespan]::FromMinutes(5); $expiry.Start()
}
function New-AnswerButton([string]$Text) {
    $b = New-Object Windows.Controls.Button
    $label = New-Object Windows.Controls.TextBlock
    $label.Text = $Text; $label.TextWrapping = 'Wrap'
    $b.Content = $label
    $b.HorizontalContentAlignment = 'Left'
    $b.Padding = '12,9'; $b.Margin = '0,4,0,4'
    $b.Background = '#303829'; $b.Foreground = '#F4F1E7'
    return $b
}
function Show-Question($Q) {
    $script:question = $Q; $script:answered = $false
    $script:popupState = 'question'
    $popup.FindName('Categories').Visibility = 'Collapsed'
    $popup.FindName('Prompt').Text = [uri]::UnescapeDataString($Q.question)
    $popup.FindName('Status').Text = ([uri]::UnescapeDataString($Q.category)) + ' / ' + $Q.difficulty
    $popup.FindName('Answers').Children.Clear()
    $script:answerButtons = @()
    $choices = @(@{Text=[uri]::UnescapeDataString($Q.correct_answer); Correct=$true})
    foreach ($answer in $Q.incorrect_answers) { $choices += @{Text=[uri]::UnescapeDataString($answer); Correct=$false} }
    foreach ($choice in ($choices | Sort-Object {Get-Random})) {
        $b = New-AnswerButton $choice.Text
        $b.Tag = $choice
        $b.Add_Click({ param($sender,$eventArgs) Submit-Answer $sender })
        $script:answerButtons += $b
        $null = $popup.FindName('Answers').Children.Add($b)
    }
    $popup.UpdateLayout(); Position-Popup
    $expiry.Stop(); $expiry.Interval = [timespan]::FromMinutes(5); $expiry.Start()
}
function Submit-Answer($Button) {
    if ($script:answered -or -not $script:question) { return }
    $script:answered = $true; $script:popupState = 'answer'
    foreach ($b in $script:answerButtons) {
        $b.IsEnabled = $false
        if ($b.Tag.Correct) { $b.Background = '#D6FA83'; $b.Foreground = '#17200C' }
        elseif ($b -eq $Button) { $b.Background = '#FFAAA0'; $b.Foreground = '#32120D' }
    }
    $prefix = if ($Button.Tag.Correct) { 'Exactly right! ' } else { 'A fact for next time. ' }
    $popup.FindName('Feedback').Text = $prefix + 'Answer: ' + [uri]::UnescapeDataString($script:question.correct_answer)
    $popup.FindName('Status').Text = 'Closing in 12 seconds. Next prompt in ' + $script:intervalMinutes + ' minutes.'
    $popup.UpdateLayout(); Position-Popup
    $expiry.Stop(); $expiry.Interval = [timespan]::FromSeconds(12); $expiry.Start()
}
function Fetch-Question([string]$Category) {
    if ($script:pending) { return }
    if (([datetime]::Now - $script:lastRequest).TotalSeconds -lt 6) {
        $popup.FindName('Status').Text = 'Please wait a few seconds, then choose your topic again.'
        return
    }
    $script:lastRequest = [datetime]::Now
    $popup.FindName('Categories').IsEnabled = $false
    $popup.FindName('Status').Text = 'Finding a fresh question...'
    try {
        $nodePath = (Get-Command node.exe -ErrorAction Stop).Source
        $startInfo = New-Object Diagnostics.ProcessStartInfo
        $startInfo.FileName = $nodePath
        $startInfo.Arguments = '--use-system-ca "' + (Join-Path $PSScriptRoot 'fetch-question.cjs') + '" "' + $Category + '"'
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.StandardOutputEncoding = [Text.Encoding]::UTF8
        $script:networkProcess = [Diagnostics.Process]::Start($startInfo)
        $script:pending = $script:networkProcess.StandardOutput.ReadToEndAsync()
        $script:networkError = $script:networkProcess.StandardError.ReadToEndAsync()
        $script:requestStarted = [datetime]::Now
        $poll.Start()
    } catch {
        Cancel-Request
        $popup.FindName('Categories').IsEnabled = $true
        $popup.FindName('Status').Text = 'Could not connect. Check your internet and pick a topic to retry.'
    }
}
function Poll-Question {
    if (-not $script:pending) { $poll.Stop(); return }
    if (-not $script:pending.IsCompleted -or -not $script:networkProcess.HasExited) {
        if (([datetime]::Now - $script:requestStarted).TotalSeconds -gt 20) {
            Cancel-Request
            $popup.FindName('Categories').IsEnabled = $true
            $popup.FindName('Status').Text = 'The request timed out. Pick a topic to try again.'
        }
        return
    }
    $poll.Stop()
    try {
        if ($script:networkProcess.ExitCode -ne 0) { throw 'Could not reach the question service.' }
        $data = $script:pending.GetAwaiter().GetResult() | ConvertFrom-Json
        if ($data.response_code -ne 0 -or @($data.results).Count -ne 1) { throw 'The trivia service is busy. Pick a topic to retry in a few seconds.' }
        $q = $data.results[0]
        if (-not $q.question -or -not $q.correct_answer -or @($q.incorrect_answers).Count -ne 3) { throw 'The trivia service returned an incomplete question. Please retry.' }
        Show-Question $q
    } catch {
        $popup.FindName('Categories').IsEnabled = $true
        $popup.FindName('Status').Text = 'Could not load a question. Check your connection, then pick a topic to retry.'
    } finally { Cancel-Request }
}
function Stop-Game {
    $script:closing = $true
    $reminder.Stop(); $expiry.Stop(); $fade.Stop(); Cancel-Request
    $tray.Visible = $false; $tray.Dispose()
    if ($script:ownsMutex) { $script:mutex.ReleaseMutex(); $script:ownsMutex = $false }
    if ($script:mutex) { $script:mutex.Dispose(); $script:mutex = $null }
    $popup.Close(); $menu.Close()
    if ([Windows.Application]::Current) { [Windows.Application]::Current.Shutdown() }
}
function Start-Background {
    $script:intervalMinutes = [int]$menu.FindName('Interval').SelectedItem.Tag
    $script:mutex = New-Object Threading.Mutex($false, 'Local\RabbitHoleBackgroundTrivia')
    try { $script:ownsMutex = $script:mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $script:ownsMutex = $true }
    if (-not $script:ownsMutex) {
        $null = [Windows.MessageBox]::Show('Rabbit Hole is already running. Look for its icon in the system tray (or the hidden-icons arrow).', 'Rabbit Hole')
        Stop-Game
        return
    }
    $script:background = $true; $script:paused = $false
    $tray.Visible = $true
    $menu.Hide()
    Schedule-Next
    $tray.ShowBalloonTip(5000, 'Rabbit Hole is running', ('First question in ' + $script:intervalMinutes + ' minutes. Right-click this tray icon for Question now, Pause, or Quit.'), [Windows.Forms.ToolTipIcon]::Info)
}

foreach ($entry in @(@('','Everything'),@('15','Gaming'),@('20','Mythology'),@('18','Computers & code'),@('24','Politics'),@('23','History'),@('21','Sports'),@('17','Science'))) {
    $b = New-AnswerButton $entry[1]
    $b.Margin = '0,3,6,3'; $b.Padding = '9,6'; $b.Tag = $entry[0]
    $b.Add_Click({param($sender,$eventArgs) Fetch-Question ([string]$sender.Tag)})
    $null = $popup.FindName('Categories').Children.Add($b)
}
$menu.FindName('Play').Add_Click({ Start-Process -FilePath $script:gamePath; Stop-Game })
$menu.FindName('Background').Add_Click({ Start-Background })
$menu.Add_Closed({ if (-not $script:closing) { Stop-Game } })
$popup.Add_SizeChanged({ Position-Popup })
$popup.Add_Closing({ param($sender,$e) if (-not $script:closing) { $e.Cancel = $true; Dismiss-Popup } })
$popup.FindName('Dismiss').Add_Click({ Dismiss-Popup })
$popup.FindName('Teaser').Add_Click({ Expand-Popup })
$popup.Add_PreviewKeyDown({param($sender,$e) if ($e.Key -eq 'Escape') { Dismiss-Popup; $e.Handled = $true }})
$reminder.Add_Tick({ Show-Reminder })
$expiry.Add_Tick({ Begin-Fade })
$fade.Add_Tick({ $popup.Opacity = [math]::Max(0, $popup.Opacity - 0.08); if ($popup.Opacity -le 0) { Dismiss-Popup } })
$poll.Add_Tick({ Poll-Question })
$nowItem.Add_Click({ Show-Reminder })
$tray.Add_DoubleClick({ Show-Reminder })
$pauseItem.Add_Click({
    $script:paused = -not $script:paused
    if ($script:paused) { Dismiss-Popup; $pauseItem.Text = 'Resume reminders'; $tray.Text = 'Rabbit Hole - paused' }
    else { $pauseItem.Text = 'Pause reminders'; $tray.Text = 'Rabbit Hole - background trivia'; Schedule-Next }
})
$playItem.Add_Click({ Start-Process -FilePath $script:gamePath })
$quitItem.Add_Click({ Stop-Game })

if ($SelfTest) {
    # Mechanics-only fixture, not a trivia question or saved question collection.
    $fixture = [pscustomobject]@{question='Test%20prompt';correct_answer='A';incorrect_answers=@('B','C','D');category='Test';difficulty='easy'}
    $script:background = $true
    Schedule-Next
    if ($reminder.Interval.TotalMinutes -ne 15 -or -not $reminder.IsEnabled) { throw 'Reminder schedule failed' }
    Show-Question $fixture
    if ($script:answerButtons.Count -ne 4) { throw 'Answer creation failed' }
    Submit-Answer ($script:answerButtons | Where-Object {$_.Tag.Correct})
    if (-not $script:answered -or $expiry.Interval.TotalSeconds -ne 12) { throw 'Answer feedback failed' }
    Dismiss-Popup
    if ($script:question -or $popup.FindName('Answers').Children.Count) { throw 'Question clearing failed' }
    if ($OnlineTest) {
        Fetch-Question '15'
        while ($script:pending) { Start-Sleep -Milliseconds 150; Poll-Question }
        if ($script:popupState -ne 'question' -or -not $script:question) { throw 'Live background fetch failed' }
        Write-Output 'PASS: live asynchronous question fetch through the background game.'
        Dismiss-Popup
    }
    $script:paused = $true; Schedule-Next
    if ($reminder.IsEnabled) { throw 'Pause failed' }
    Stop-Game
    Write-Output 'PASS: WPF construction, 15-minute scheduling, four answers, feedback, dismissal, memory clearing, pause and cleanup.'
    exit 0
}
$app = New-Object Windows.Application
$app.ShutdownMode = 'OnExplicitShutdown'
try { $menu.Show(); $null = $app.Run() }
finally { if (-not $script:closing) { Stop-Game } }
