#!/bin/bash

iconSizes="
16,16x16
32,32x32
128,128x128
256,256x256
512,512x512
1024,1024x1024
64,32x32@2x
128,64x64@2x
512,256x256@2x
1024,512x512@2x
2048,1024x1024@2x
"

tmpDir=$(mktemp -d)

svgFiles=$1
for svgFile in $svgFiles
do
    echo "Processing $svgFile file..."
    iconSet="$(basename $svgFile | sed 's/\.[^\.]*$//').iconset"
    iconSetDir="$tmpDir/icons/$iconSet"
    icon="$(basename $svgFile | sed 's/\.[^\.]*$//').icns"
    iconFile="$(dirname $svgFile)/$icon"
    mkdir -p "$iconSetDir"
    for sizesRec in $iconSizes; do
        iconSize=$(echo $sizesRec | cut -d, -f1)
        iconLabel=$(echo $sizesRec | cut -d, -f2)
#        svg2png -w $iconSize -h $iconSize "$svgFile" "$iconSetDir"/icon_$iconLabel.png || true
#        qlmanage -t -s $iconSize -o "$iconSetDir" "$svgFile" && mv -v "$iconSetDir/$svgFile.png" "$iconSetDir/icon_$iconLabel.png"
        echo "Executing: rsvg-convert -h $iconSize \"$svgFile\" > \"$iconSetDir\"/icon_$iconLabel.png"
        rsvg-convert -h $iconSize "$svgFile" > "$iconSetDir"/icon_$iconLabel.png || true
    done

    iconutil -c icns -o "$iconFile" "$iconSetDir" || true
    rm -rf "$iconSetDir"
done

rm -rf $tmpDir
