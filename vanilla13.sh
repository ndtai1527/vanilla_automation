dir=$(pwd)
repS="python3 $work_dir/bin/strRep.py"
mkdir -p $dir/jar_temp

jar_util() 
{
	cd $dir
	#binary
	if [[ $3 == "fw" ]]; then 
		bak="java -jar $dir/bin/baksmali.jar d --api 33"
		sma="java -jar $dir/bin/smali.jar a --api 33"
	fi

	if [[ $1 == "d" ]]; then
		echo -ne "====> Patching $2 : "
		if [[ -f $dir/framework.jar ]]; then
			sudo cp $dir/framework.jar $dir/jar_temp
			sudo chown $(whoami) $dir/jar_temp/$2
			unzip $dir/jar_temp/$2 -d $dir/jar_temp/$2.out  >/dev/null 2>&1
			if [[ -d $dir/jar_temp/"$2.out" ]]; then
				rm -rf $dir/jar_temp/$2
				for dex in $(find $dir/jar_temp/"$2.out" -maxdepth 1 -name "*dex" ); do
						if [[ $4 ]]; then
							if [[ ! "$dex" == *"$4"* ]]; then
								$bak $dex -o "$dex.out"
								[[ -d "$dex.out" ]] && rm -rf $dex
							fi
						else
							$bak $dex -o "$dex.out"
							[[ -d "$dex.out" ]] && rm -rf $dex		
						fi

				done
			fi
		fi
	else 
		if [[ $1 == "a" ]]; then 
			if [[ -d $dir/jar_temp/$2.out ]]; then
				cd $dir/jar_temp/$2.out
				for fld in $(find -maxdepth 1 -name "*.out" ); do
					if [[ $4 ]]; then
						if [[ ! "$fld" == *"$4"* ]]; then
							$sma $fld -o $(echo ${fld//.out})
							[[ -f $(echo ${fld//.out}) ]] && rm -rf $fld
						fi
					else 
						$sma $fld -o $(echo ${fld//.out})
						[[ -f $(echo ${fld//.out}) ]] && rm -rf $fld	
					fi
				done
				7za a -tzip -mx=0 $dir/jar_temp/$2_notal $dir/jar_temp/$2.out/. >/dev/null 2>&1
				#zip -r -j -0 $dir/jar_temp/$2_notal $dir/jar_temp/$2.out/.
				zipalign 4 $dir/jar_temp/$2_notal $dir/jar_temp/$2
				if [[ -f $dir/jar_temp/$2 ]]; then
					sudo cp -rf $dir/jar_temp/$2 $dir/module/system/framework
					final_dir="$dir/module/*"
					#7za a -tzip "$dir/services_patched_$(date "+%d%m%y").zip" $final_dir
					echo "Success"
					rm -rf $dir/jar_temp/$2.out $dir/jar_temp/$2_notal 
				else
					echo "Fail"
				fi
			fi
		fi
	fi
}
CLASSES4_DEX="$dir/cts13/classes4.dex"
TMP_DIR="$dir/jar_temp"
CLASSES4_DIR="$dir/jar_temp/classes4.out"
FRAMEWORK_DIR="$dir/jar_temp/framework.jar.out"


# Create the classes4.out directory if it doesn't exist
if [ ! -d "$CLASSES4_DIR" ]; then
    mkdir -p "$CLASSES4_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create directory $CLASSES4_DIR"
        exit 1
    fi
fi

echo "Disassembling framework.jar"
jar_util d "framework.jar" fw

echo "Disassembling classes4.dex"
java -jar $dir/bin/baksmali.jar d "$CLASSES4_DEX" -o "$CLASSES4_DIR"

if [[ ! -d "$CLASSES4_DIR" ]]; then
    echo "Error: Failed to disassemble classes4.dex"
    exit 1
fi


# Find and copy specific .smali files
files_to_copy=("ApplicationPackageManager.smali" "Instrumentation.smali" "AndroidKeyStoreSpi.smali")

for file in "${files_to_copy[@]}"; do
    framework_file=$(find "$FRAMEWORK_DIR" -name "$(basename $file)")
    classes4_file=$(find "$CLASSES4_DIR" -name "$(basename $file)")
    
    if [[ -f "$classes4_file" ]]; then
        echo "Copying $classes4_file to $framework_file"
        cp -rf "$classes4_file" "$framework_file"
    else
        echo "Error: $classes4_file not found"
    fi
done

util_folder=$(find "$FRAMEWORK_DIR" -type d -path "*/com/android/internal/util")

if [[ -d "$util_folder" ]]; then
    summert_folder="$util_folder/summert"
    mkdir -p "$summert_folder"
    
    files_to_copy_to_summert=(
        "AttestationHooks.smali"
        "GamesPropsUtils.smali"
        "PixelPropsUtils.smali"
        "PixelPropsUtils\$1.smali"
        "PixelPropsUtils\$\$ExternalSyntheticLambda0.smali"
        "PixelPropsUtils\$\$ExternalSyntheticLambda1.smali"
        "AttestationHooks\$\$ExternalSyntheticLambda0.smali"
    )
    for file in "${files_to_copy_to_summert[@]}"; do
        classes4_file=$(find "$CLASSES4_DIR" -name "$file")
        
        if [[ -f "$classes4_file" ]]; then
            echo "Copying $classes4_file to $summert_folder"
            cp "$classes4_file" "$summert_folder"
        else
            echo "Error: $classes4_file not found"
        fi
    done
else
    echo "Error: util folder not found in framework"
fi

echo "Assembling framework.jar"
jar_util a "framework.jar" fw

rm -rf $work_dir/jar_temp

