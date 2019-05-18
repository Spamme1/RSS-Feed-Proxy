[cmdletbinding()]
#https://4sysops.com/archives/how-to-run-a-powershell-script-as-a-windows-service/
#https://bernhardelbl.wordpress.com/2014/07/03/string-to-guid-a-md5-hash-for-net-and-sql-server/
param()

Import-Module -Name Polaris

function getRank($source)
{
	$rank=0
	if ($source -match "uhd") {$rank=30} 
	elseif ($source -match "bluray") {$rank=20}
	elseif ($source -match "web") {$rank=10}
	$rank 
}

function getEncoding($enc)
{
	$val=0
	if ($enc -eq "x265" -or $enc -eq "h265" -or $enc -eq "hvec") { $val=30 }
	elseif ($enc -eq "x264" -or $enc -eq "h264" -or $enc -eq "avc") { $val=20 }
	elseif ($enc -eq "xvid") { $val=10 }
	$val
}

function removeDuplicates($xml,$arr)
{
	$arr=$arr | Sort-Object title,res,enc,rank -D
	#write-host ($arr | Format-Table | Out-String)
	$title=""
	foreach($movie in $arr)
	{
		if ($title -ne $movie.title) { $title=$movie.title }
		else 
		{
			$node=$xml.SelectSingleNode("//rss/channel/item/guid[text()='"+$movie.guid+"']")
			$node.parentNode.parentNode.removeChild($node.parentNode)
		}
	}
	$xml
}

New-PolarisGetRoute -Path "/rarbg" -Scriptblock {
    $wc=New-Object System.Net.WebClient
	$cats=$Request.Query["Categories"] -split ";"
	$url="http://rarbg.to/rssdd.php?categories="
	$movies=@{}
	$xml=$Null
	# $wc.Headers.Add("user-agent","Mozilla/5.0 (platform; rv:geckoversion) Gecko/geckotrail Firefox/firefoxversion")
	# $text=$wc.DownloadString($url+$Request.Query["Categories"])
	# $Response.ContentType="text/xml"
	# $Response.Send($text)
	foreach ($cat in $cats)
	{
		$wc.Headers.Add("user-agent","Mozilla/5.0 (platform; rv:geckoversion) Gecko/geckotrail Firefox/firefoxversion")
		$xml_temp=[XML]$wc.DownloadString($url+$cat)
		if ($xml -eq $Null) { $xml=$xml_temp; }
		else { foreach($child in $xml_temp.rss.channel.item) { [void]$xml.rss.channel.AppendChild($xml.ImportNode($child,$True)) }}
	}
	#foreach($child in $xml.rss.channel.item) { write-host $child.title }
	$arr=$xml.rss.channel.item | select guid,@{Name="regex";Expression={[regex]::Match($_.title,"(.*\.(?:19|20)\d\d)\.(?:.*?)(\d{3,4})p\.(.*?)\.(xvid|x264|h264|x265|h265|avc|hevc)",[Text.RegularExpressions.RegexOptions]::IgnoreCase)}} | select guid,@{Name="title";Expression={$_.regex.Groups[1].Value}},@{Name="res";Expression={$_.regex.Groups[2].Value}},@{Name="src";Expression={$_.regex.Groups[3].Value}},@{Name="enc";Expression={getEncoding $_.regex.Groups[4].Value }},@{Name="rank";Expression={getRank $_.regex.Groups[3].Value}}
	removeDuplicates $xml $arr
	$Response.ContentType="text/xml"
	$Response.Send($xml.rss.OuterXml)
}

New-PolarisGetRoute -Path "/yts/*" -Scriptblock {
    $wc=New-Object System.Net.WebClient
	$path=$Request.Parameters.0
	$path=$path.Substring(4)
	#write-host ($path)
	$wc.Headers.Add("user-agent","Mozilla/5.0 (platform; rv:geckoversion) Gecko/geckotrail Firefox/firefoxversion")
	$xml=[XML]$wc.DownloadString("https://yts.am"+$path)
	$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
	foreach($item in $xml.rss.channel.item) 
	{ 
		$hash=$md5.ComputeHash([System.Text.Encoding]::Default.GetBytes($item.title.'#cdata-section'))
		$item.guid=([Guid]::New($hash)).ToString()
	}
	$arr=$xml.rss.channel.item | select guid,@{Name="regex";Expression={[regex]::Match($_.title.'#cdata-section',"(.*? \(\d{4}\)) \[(.*?)\] \[(\d+)p\]")}} | select guid,@{Name="title";Expression={$_.regex.Groups[1].Value}},@{Name="res";Expression={$_.regex.Groups[3].Value}},@{Name="src";Expression={$_.regex.Groups[2].Value}},@{Name="enc";Expression={264}},@{Name="rank";Expression={getRank $_.regex.Groups[2].Value }}
	removeDuplicates $xml $arr
	$Response.ContentType="text/xml"
	$Response.Send($xml.rss.OuterXml)
 }
 

Start-Polaris -Port 6060
 
while($true) {
    Start-Sleep -Milliseconds 10
}