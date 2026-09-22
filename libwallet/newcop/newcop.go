package newcop

// Init es el punto de entrada exportado del paquete newcop.
// gomobile bind requiere al menos un símbolo público (con mayúscula
// inicial) para poder generar el binding para Android.
func Init() string {
	return "newcop initialized"
}
