/*
 * List of native methods built-in to the runtime.  These must be in
 * ascending lexical order because binary search is used for lookup.
 * 
 * Dots must be changed to underscore chars.  For example the method abc
 * in the class Myclass in the package my.package should be named :-
 *    my_package_Myclass_abc
 */

NativeDef(io_DescStream_flag_impl)
NativeDef(io_DescStream_poll_impl)
NativeDef(io_DescStream_select_impl)
NativeDef(io_DirStream_close_impl)
NativeDef(io_DirStream_open_impl)
NativeDef(io_DirStream_read_impl)
NativeDef(io_FileStream_close_impl)
NativeDef(io_FileStream_in_impl)
NativeDef(io_FileStream_open_impl)
NativeDef(io_FileStream_out_impl)
NativeDef(io_FileStream_seek_impl)
NativeDef(io_ProgStream_close_impl)
NativeDef(io_ProgStream_open_impl)
NativeDef(io_SocketStream_accept_impl)
NativeDef(io_SocketStream_bind_impl)
NativeDef(io_SocketStream_close_impl)
NativeDef(io_SocketStream_connect_impl)
NativeDef(io_SocketStream_in_impl)
NativeDef(io_SocketStream_listen_impl)
NativeDef(io_SocketStream_out_impl)
NativeDef(io_SocketStream_socket_impl)
NativeDef(io_SocketStream_socketpair_impl)
NativeDef(lang_Class_complete_raw)
NativeDef(lang_Class_create_raw)
NativeDef(lang_Class_ensure_initialized)
NativeDef(lang_Class_for_name)
NativeDef(lang_Class_get)
NativeDef(lang_Class_get_cast_class)
NativeDef(lang_Class_get_cast_object)
NativeDef(lang_Class_get_class_field_names)
NativeDef(lang_Class_get_class_flags)
NativeDef(lang_Class_get_field_defining_class)
NativeDef(lang_Class_get_field_flags)
NativeDef(lang_Class_get_field_index)
NativeDef(lang_Class_get_field_name)
NativeDef(lang_Class_get_field_names)
NativeDef(lang_Class_get_implemented_classes)
NativeDef(lang_Class_get_instance_field_names)
NativeDef(lang_Class_get_methp_object)
NativeDef(lang_Class_get_methp_proc)
NativeDef(lang_Class_get_n_class_fields)
NativeDef(lang_Class_get_n_fields)
NativeDef(lang_Class_get_n_instance_fields)
NativeDef(lang_Class_get_supers)
NativeDef(lang_Class_getf)
NativeDef(lang_Class_set_method)
NativeDef(parser_UReader_raw_convert)
#if MSWIN32
NativeDef(util_WindowsFilePath_getdcwd)
NativeDef(util_WindowsFileSystem_get_roots)
#endif
