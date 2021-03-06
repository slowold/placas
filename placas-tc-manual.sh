#/bin/bash
#
# Este Script ejecuta manualmente la inserción de placas y overlays sobre un video.
#	USO:	placas-tc-manual.sh {Video de entrada}
#

if [ "$1" = "" ]; then
	echo "ERROR: No se especificó archivo."
	echo "USO: placas-tc-manual.sh {Archivo}"
	exit 1
fi

ARG=$1
ARGFNAME=${ARG%.*}

# Cargar configuración
source /etc/placas-tc.conf

# Funciones
function loguear {
	echo "$(date +'%H:%M:%S') $1" >> "$LOG"
}

# Contar placas
cntin=$(find "$PLACAS_IN" -maxdepth 1 -name '*.mxf' 2>/dev/null | wc -l)
cntout=$(find "$PLACAS_OUT" -maxdepth 1 -name '*.mxf' 2>/dev/null | wc -l)
cntlay=$(find "$LAYERS" -maxdepth 1 -name '*.png' 2>/dev/null  | wc -l)

if [ "$cntin" = "0" ] && [ "$cntout" = "0" ] && [ "$cntlay" = "0" ]; then
	loguear "ERROR: Se intentó ejecutar, pero no se encontraron ni placas ni overlays."
	echo "ERROR: No se encontraron placas ni overlays."
	exit 1
fi

# Inicio de ejecución
loguear "--- EJECUCIÓN MANUAL ---"
loguear "Se inicia ejecución con $cntin placas de entrada, $cntout de salida y $cntlay overlays."

PLACAS_IN_STR=""
PLACAS_OUT_STR=""
LAYERS_STR=""
FILTRO=""
vconcat="[0:0]"			# Stream de video. Por defecto, [0:0], si hay overlays cambia.
al=1
OUTVS=""
OUTAS1="0:1"
OUTAS2="0:2"

if [ "$cntlay" != "0" ]; then
	for i in "$LAYERS"/*.png; do
		LAYERS_STR="$LAYERS_STR -i \"$i\""
		if [ $al = 1 ]; then
			FILTRO="$FILTRO[0:0][1:0] overlay [vo$al]"
		else
			FILTRO="$FILTRO; [vo$((al-1))][$al:0] overlay [vo$al]"
		fi
		vconcat="[vo$al]"
		OUTVS="[vo$al]"
		((al++))
	done
fi

if [ "$cntin" != "0" ] || [ "$cntout" != "0" ]; then 		# Verificar si hay placas para poner
	concant=1		# Cantidad de archivos a concatenar. Empieza en 1 y crece.
	ain=$al
	if [ "$FILTRO" != "" ]; then
		FILTRO="$FILTRO; "
	fi
	
	if [ "$cntin" != "0" ]; then 		# Si hay placas de adelante
		for i in "$PLACAS_IN"/*.mxf; do
			PLACAS_IN_STR="$PLACAS_IN_STR -i \"$i\""
			FILTRO="$FILTRO[$ain:0][$ain:1][$ain:2]"
			((ain++))
			((concant++))
		done
	fi

	FILTRO="$FILTRO$vconcat[0:1][0:2]"

	if [ "$cntout" != "0" ]; then		# Si hay placas de atrás
		for i in "$PLACAS_OUT"/*.mxf; do
			PLACAS_OUT_STR="$PLACAS_OUT_STR -i \"$i\""
			FILTRO="$FILTRO[$ain:0][$ain:1][$ain:2]"
			((ain++))
			((concant++))
		done
	fi
	
	FILTRO="$FILTRO concat=n=$concant:v=1:a=2 [v] [a1] [a2]"
	OUTVS="[v]"
	OUTAS1="[a1]"
	OUTAS2="[a2]"
fi

FFSTRING="$FFMPEG $OPTSIN -i $1 $LAYERS_STR $PLACAS_IN_STR $PLACAS_OUT_STR -c:v $CV -b:v $BRV -c:a $CA -b:a $BRA -filter_complex \"$FILTRO\" -map '$OUTVS' -map '$OUTAS1' -map '$OUTAS2' $OUTV/$ARGFNAME.$FMT" # Armar el string que se va a usar para transcodear

eval $FFSTRING

loguear "--- FIN DE EJECUCION MANUAL ---"