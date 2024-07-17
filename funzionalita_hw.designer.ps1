$Form1 = New-Object -TypeName System.Windows.Forms.Form
[System.Windows.Forms.TextBox]$TextBox1 = $null
[System.Windows.Forms.TextBox]$TextBox2 = $null
[System.Windows.Forms.TextBox]$TextBox3 = $null
[System.Windows.Forms.TextBox]$TextBox4 = $null
[System.Windows.Forms.TextBox]$TextBox5 = $null
[System.Windows.Forms.TextBox]$TextBox6 = $null
[System.Windows.Forms.TextBox]$TextBox7 = $null
[System.Windows.Forms.TextBox]$TextBox8 = $null
[System.Windows.Forms.TextBox]$TextBox9 = $null
[System.Windows.Forms.TextBox]$TextBox11 = $null
[System.Windows.Forms.TextBox]$TextBox12 = $null
[System.Windows.Forms.TextBox]$TextBox13 = $null
[System.Windows.Forms.TextBox]$TextBox14 = $null
[System.Windows.Forms.TextBox]$TextBox10 = $null
function InitializeComponent
{
$TextBox1 = (New-Object -TypeName System.Windows.Forms.TextBox)
$TextBox2 = (New-Object -TypeName System.Windows.Forms.TextBox)
$TextBox3 = (New-Object -TypeName System.Windows.Forms.TextBox)
$TextBox4 = (New-Object -TypeName System.Windows.Forms.TextBox)
$TextBox5 = (New-Object -TypeName System.Windows.Forms.TextBox)
$TextBox6 = (New-Object -TypeName System.Windows.Forms.TextBox)
$TextBox7 = (New-Object -TypeName System.Windows.Forms.TextBox)
$TextBox8 = (New-Object -TypeName System.Windows.Forms.TextBox)
$TextBox9 = (New-Object -TypeName System.Windows.Forms.TextBox)
$TextBox11 = (New-Object -TypeName System.Windows.Forms.TextBox)
$TextBox12 = (New-Object -TypeName System.Windows.Forms.TextBox)
$TextBox13 = (New-Object -TypeName System.Windows.Forms.TextBox)
$TextBox14 = (New-Object -TypeName System.Windows.Forms.TextBox)
$TextBox10 = (New-Object -TypeName System.Windows.Forms.TextBox)
$Form1.SuspendLayout()
#
#TextBox1
#
$TextBox1.Anchor = ([System.Windows.Forms.AnchorStyles][System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right)
$TextBox1.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]272))
$TextBox1.Multiline = $true
$TextBox1.Name = [System.String]'TextBox1'
$TextBox1.ReadOnly = $true
$TextBox1.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$TextBox1.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]768,[System.Int32]271))
$TextBox1.TabIndex = [System.Int32]1
#
#TextBox2
#
$TextBox2.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$TextBox2.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]12))
$TextBox2.Name = [System.String]'TextBox2'
$TextBox2.ReadOnly = $true
$TextBox2.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]384,[System.Int32]14))
$TextBox2.TabIndex = [System.Int32]2
$TextBox2.Text = [System.String]'CONSOLE INI NOT ALIGNED'
#
#TextBox3
#
$TextBox3.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$TextBox3.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]32))
$TextBox3.Name = [System.String]'TextBox3'
$TextBox3.ReadOnly = $true
$TextBox3.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]384,[System.Int32]14))
$TextBox3.TabIndex = [System.Int32]3
$TextBox3.Text = [System.String]'Informazioni:'
$TextBox3.add_TextChanged($TextBox3_TextChanged)
#
#TextBox4
#
$TextBox4.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$TextBox4.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]29,[System.Int32]72))
$TextBox4.Name = [System.String]'TextBox4'
$TextBox4.ReadOnly = $true
$TextBox4.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]367,[System.Int32]14))
$TextBox4.TabIndex = [System.Int32]4
$TextBox4.Text = [System.String]'Collegamento Unico Attivo'
#
#TextBox5
#
$TextBox5.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$TextBox5.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]29,[System.Int32]152))
$TextBox5.Name = [System.String]'TextBox5'
$TextBox5.ReadOnly = $true
$TextBox5.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]367,[System.Int32]14))
$TextBox5.TabIndex = [System.Int32]5
$TextBox5.Text = [System.String]'Indirizzo IP inserito dentro INIT: 10.0.0.84'
$TextBox5.add_TextChanged($TextBox5_TextChanged)
#
#TextBox6
#
$TextBox6.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$TextBox6.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]192))
$TextBox6.Name = [System.String]'TextBox6'
$TextBox6.ReadOnly = $true
$TextBox6.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]384,[System.Int32]14))
$TextBox6.TabIndex = [System.Int32]6
$TextBox6.Text = [System.String]'Servizi:'
$TextBox6.add_TextChanged($TextBox6_TextChanged)
#
#TextBox7
#
$TextBox7.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$TextBox7.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]132))
$TextBox7.Name = [System.String]'TextBox7'
$TextBox7.ReadOnly = $true
$TextBox7.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]384,[System.Int32]14))
$TextBox7.TabIndex = [System.Int32]7
$TextBox7.Text = [System.String]'Indirizzi IP:'
$TextBox7.add_TextChanged($TextBox7_TextChanged)
#
#TextBox8
#
$TextBox8.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$TextBox8.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]29,[System.Int32]92))
$TextBox8.Name = [System.String]'TextBox8'
$TextBox8.ReadOnly = $true
$TextBox8.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]367,[System.Int32]14))
$TextBox8.TabIndex = [System.Int32]8
$TextBox8.Text = [System.String]'Sono Presenti Nodi, questo è il nodo: 0'
#
#TextBox9
#
$TextBox9.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$TextBox9.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]29,[System.Int32]212))
$TextBox9.Name = [System.String]'TextBox9'
$TextBox9.ReadOnly = $true
$TextBox9.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]367,[System.Int32]14))
$TextBox9.TabIndex = [System.Int32]9
$TextBox9.Text = [System.String]'OSLRDServer service is Stopped'
#
#TextBox11
#
$TextBox11.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$TextBox11.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]29,[System.Int32]172))
$TextBox11.Name = [System.String]'TextBox11'
$TextBox11.ReadOnly = $true
$TextBox11.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]367,[System.Int32]14))
$TextBox11.TabIndex = [System.Int32]11
$TextBox11.Text = [System.String]'Firewall Active'
#
#TextBox12
#
$TextBox12.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$TextBox12.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]29,[System.Int32]52))
$TextBox12.Name = [System.String]'TextBox12'
$TextBox12.ReadOnly = $true
$TextBox12.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]367,[System.Int32]14))
$TextBox12.TabIndex = [System.Int32]12
$TextBox12.Text = [System.String]'Segnali su Tabella disattivato'
#
#TextBox13
#
$TextBox13.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$TextBox13.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]12,[System.Int32]252))
$TextBox13.Name = [System.String]'TextBox13'
$TextBox13.ReadOnly = $true
$TextBox13.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]384,[System.Int32]14))
$TextBox13.TabIndex = [System.Int32]13
$TextBox13.Text = [System.String]'Password: 1234-i4qfis-6in7'
#
#TextBox14
#
$TextBox14.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$TextBox14.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]29,[System.Int32]112))
$TextBox14.Name = [System.String]'TextBox14'
$TextBox14.ReadOnly = $true
$TextBox14.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]367,[System.Int32]14))
$TextBox14.TabIndex = [System.Int32]14
$TextBox14.Text = [System.String]'Debug Log disattivato'
#
#TextBox10
#
$TextBox10.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$TextBox10.Location = (New-Object -TypeName System.Drawing.Point -ArgumentList @([System.Int32]29,[System.Int32]232))
$TextBox10.Name = [System.String]'TextBox10'
$TextBox10.ReadOnly = $true
$TextBox10.Size = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]367,[System.Int32]14))
$TextBox10.TabIndex = [System.Int32]15
$TextBox10.Text = [System.String]'OverOne Monitoring Service is not installed on this computer.'
#
#Form1
#
$Form1.ClientSize = (New-Object -TypeName System.Drawing.Size -ArgumentList @([System.Int32]792,[System.Int32]555))
$Form1.Controls.Add($TextBox10)
$Form1.Controls.Add($TextBox14)
$Form1.Controls.Add($TextBox13)
$Form1.Controls.Add($TextBox12)
$Form1.Controls.Add($TextBox11)
$Form1.Controls.Add($TextBox9)
$Form1.Controls.Add($TextBox8)
$Form1.Controls.Add($TextBox7)
$Form1.Controls.Add($TextBox6)
$Form1.Controls.Add($TextBox5)
$Form1.Controls.Add($TextBox4)
$Form1.Controls.Add($TextBox3)
$Form1.Controls.Add($TextBox2)
$Form1.Controls.Add($TextBox1)
$Form1.Text = [System.String]'OSL Debugger'
$Form1.ResumeLayout($false)
$Form1.PerformLayout()
Add-Member -InputObject $Form1 -Name TextBox1 -Value $TextBox1 -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name TextBox2 -Value $TextBox2 -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name TextBox3 -Value $TextBox3 -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name TextBox4 -Value $TextBox4 -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name TextBox5 -Value $TextBox5 -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name TextBox6 -Value $TextBox6 -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name TextBox7 -Value $TextBox7 -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name TextBox8 -Value $TextBox8 -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name TextBox9 -Value $TextBox9 -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name TextBox11 -Value $TextBox11 -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name TextBox12 -Value $TextBox12 -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name TextBox13 -Value $TextBox13 -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name TextBox14 -Value $TextBox14 -MemberType NoteProperty
Add-Member -InputObject $Form1 -Name TextBox10 -Value $TextBox10 -MemberType NoteProperty
}
. InitializeComponent
