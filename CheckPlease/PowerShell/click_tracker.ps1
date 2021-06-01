#
#   Waits until N mouse clicks occur before executing (default: 10), PowerShell
#   Module written by Brandon Arvanaghi
#   Website: arvanaghi.com 
#   Twitter: @arvanaghi
#

$minClicks = 10
$count = 0
if ($Args.count -eq 1) {
    $minClicks = $($args[0])
} 

$getAsyncKeyProto = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] 
public static extern short GetAsyncKeyState(int virtualKeyCode); 
'@

$getAsyncKeyState = Add-Type -MemberDefinition $getAsyncKeyProto -Name "Win32GetState" -Namespace Win32Functions -PassThru

while ($count -lt $minClicks) {
    Start-Sleep 1
    $leftClick = $getAsyncKeyState::GetAsyncKeyState(1)
    $rightClick = $getAsyncKeyState::GetAsyncKeyState(2)

    if ($leftClick) {
        $count += 1
    } 

    if ($rightClick) {
        $count += 1
    }
}

Write-Output "Now that the user has clicked $minClicks times, we may proceed with malware execution!"