#requires -Version 5.1
# Rebuild the hand-drawn magnifier icon; no external libraries required.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$sizes = @(16,20,24,32,40,48,64,128,256)
$frames = @()
foreach ($size in $sizes) {
    $bitmap = [Drawing.Bitmap]::new($size,$size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = 'AntiAlias'
    $graphics.ScaleTransform($size / 256.0, $size / 256.0)
    $purple = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#6550cc'))
    $cyan = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#85e3df'))
    $gold = [Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#ffd48b'))
    $handle = [Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#e9dcff'),31)
    $ring = [Drawing.Pen]::new([Drawing.Color]::White,19)
    $shine = [Drawing.Pen]::new([Drawing.Color]::White,10)
    $path = [Drawing.Drawing2D.GraphicsPath]::new()
    $stream = [IO.MemoryStream]::new()
    try {
        $path.AddArc(8,8,128,128,180,90); $path.AddArc(120,8,128,128,270,90)
        $path.AddArc(120,120,128,128,0,90); $path.AddArc(8,120,128,128,90,90); $path.CloseFigure()
        $graphics.FillPath($purple,$path)
        $handle.StartCap='Round'; $handle.EndCap='Round'
        $graphics.DrawLine($handle,148,148,201,201)
        $graphics.FillEllipse($cyan,45,45,122,122); $graphics.DrawEllipse($ring,45,45,122,122)
        $shine.StartCap='Round'; $shine.EndCap='Round'
        $graphics.DrawBezier($shine,78,96,81,83,88,77,101,77)
        $points = [Drawing.PointF[]]@([Drawing.PointF]::new(199,27),[Drawing.PointF]::new(207,48),
            [Drawing.PointF]::new(229,56),[Drawing.PointF]::new(207,64),[Drawing.PointF]::new(199,86),
            [Drawing.PointF]::new(191,64),[Drawing.PointF]::new(169,56),[Drawing.PointF]::new(191,48))
        $graphics.FillPolygon($gold,$points)
        $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
        $frames += ,$stream.ToArray()
        if ($size -eq 256) { $bitmap.Save((Join-Path $PSScriptRoot 'assets\TaskPlopp.png'),[Drawing.Imaging.ImageFormat]::Png) }
    } finally {
        foreach ($item in @($graphics,$bitmap,$purple,$cyan,$gold,$handle,$ring,$shine,$path,$stream)) { $item.Dispose() }
    }
}
$output = [IO.File]::Create((Join-Path $PSScriptRoot 'assets\TaskPlopp.ico'))
$writer = [IO.BinaryWriter]::new($output)
try {
    $writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($index=0; $index -lt $sizes.Count; $index++) {
        $dimension = if ($sizes[$index] -eq 256) { 0 } else { $sizes[$index] }
        $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
        $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([uint16]1); $writer.Write([uint16]32)
        $writer.Write([uint32]$frames[$index].Length); $writer.Write([uint32]$offset)
        $offset += $frames[$index].Length
    }
    foreach ($frame in $frames) { $writer.Write([byte[]]$frame) }
} finally { $writer.Dispose(); $output.Dispose() }
Write-Output 'TaskPlopp.ico mit neun Aufloesungen und PNG-Vorschau erstellt.'
