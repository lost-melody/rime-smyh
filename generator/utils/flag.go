package utils

import (
	"flag"
	"fmt"
	"log"
	"reflect"
	"strconv"
	"unsafe"
)

func ParseFlags(args interface{}) error {
	value := reflect.ValueOf(args)
	if value.Kind() != reflect.Ptr || value.IsNil() {
		return fmt.Errorf("value is not a pointer or is nil")
	}

	elem := value.Elem()
	for i := 0; i < elem.NumField(); i++ {
		fieldType := elem.Type().Field(i)
		fieldValue := elem.Field(i)
		fieldPtr := unsafe.Pointer(fieldValue.Addr().Pointer())

		flagName := fieldType.Tag.Get("flag")
		flagUsage := fieldType.Tag.Get("usage")
		flagDefault := fieldType.Tag.Get("default")

		if len(flagName) == 0 {
			flagName = fieldType.Name
		}

		switch fieldType.Type.Kind() {
		case reflect.Bool:
			value, _ := strconv.ParseBool(flagDefault)
			flag.BoolVar((*bool)(fieldPtr), flagName, value, flagUsage)
		case reflect.Int:
			value, _ := strconv.ParseInt(flagDefault, 10, 64)
			flag.IntVar((*int)(fieldPtr), flagName, int(value), flagUsage)
		case reflect.Int64:
			value, _ := strconv.ParseInt(flagDefault, 10, 64)
			flag.Int64Var((*int64)(fieldPtr), flagName, value, flagUsage)
		case reflect.Uint:
			value, _ := strconv.ParseUint(flagDefault, 10, 64)
			flag.UintVar((*uint)(fieldPtr), flagName, uint(value), flagUsage)
		case reflect.Uint64:
			value, _ := strconv.ParseUint(flagDefault, 10, 64)
			flag.Uint64Var((*uint64)(fieldPtr), flagName, value, flagUsage)
		case reflect.Float64:
			value, _ := strconv.ParseFloat(flagDefault, 64)
			flag.Float64Var((*float64)(fieldPtr), flagName, value, flagUsage)
		case reflect.String:
			flag.StringVar((*string)(fieldPtr), flagName, flagDefault, flagUsage)
		default:
			log.Printf("unsupported field `%s` of type `%s`, skipped", fieldType.Name, fieldType.Type)
		}
	}

	flag.Parse()
	return nil
}
