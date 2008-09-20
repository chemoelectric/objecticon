/*
 * List of native methods built-in to the runtime.  These must be in
 * ascending lexical order because binary search is used for lookup.
 * 
 * Dots must be changed to underscore chars.  For example the method abc
 * in the class Myclass in the package my.package should be named :-
 *    my_package_Myclass_abc
 */
NativeDef(graphics_Window_alert)
NativeDef(graphics_Window_attrib)
NativeDef(graphics_Window_bg)
NativeDef(graphics_Window_clip)
NativeDef(graphics_Window_clone_impl)
NativeDef(graphics_Window_close)
NativeDef(graphics_Window_color)
NativeDef(graphics_Window_color_value)
NativeDef(graphics_Window_copy_area)
NativeDef(graphics_Window_couple_impl)
NativeDef(graphics_Window_draw_arc)
NativeDef(graphics_Window_draw_circle)
NativeDef(graphics_Window_draw_curve)
NativeDef(graphics_Window_draw_image)
NativeDef(graphics_Window_draw_line)
NativeDef(graphics_Window_draw_point)
NativeDef(graphics_Window_draw_polygon)
NativeDef(graphics_Window_draw_rectangle)
NativeDef(graphics_Window_draw_segment)
NativeDef(graphics_Window_draw_string)
NativeDef(graphics_Window_erase_area)
NativeDef(graphics_Window_event)
NativeDef(graphics_Window_fg)
NativeDef(graphics_Window_fill_arc)
NativeDef(graphics_Window_fill_circle)
NativeDef(graphics_Window_fill_polygon)
NativeDef(graphics_Window_fill_rectangle)
NativeDef(graphics_Window_flush)
NativeDef(graphics_Window_font)
NativeDef(graphics_Window_free_color)
NativeDef(graphics_Window_generic_color_value)
NativeDef(graphics_Window_generic_palette_key)
NativeDef(graphics_Window_get_selection_content)
NativeDef(graphics_Window_lower)
NativeDef(graphics_Window_new_color)
NativeDef(graphics_Window_open_impl)
NativeDef(graphics_Window_own_selection)
NativeDef(graphics_Window_palette_chars)
NativeDef(graphics_Window_palette_color)
NativeDef(graphics_Window_palette_key)
NativeDef(graphics_Window_pattern)
NativeDef(graphics_Window_pending)
NativeDef(graphics_Window_pixel)
NativeDef(graphics_Window_query_root_pointer)
NativeDef(graphics_Window_raise)
NativeDef(graphics_Window_read_image)
NativeDef(graphics_Window_sync)
NativeDef(graphics_Window_text_width)
NativeDef(graphics_Window_uncouple)
NativeDef(graphics_Window_wdefault)
NativeDef(graphics_Window_write_image)
NativeDef(io_DescStream_flag)
NativeDef(io_DescStream_poll)
NativeDef(io_DescStream_select)
NativeDef(io_DirStream_close)
NativeDef(io_DirStream_open_impl)
NativeDef(io_DirStream_read_impl)
NativeDef(io_FileStream_close)
NativeDef(io_FileStream_in)
NativeDef(io_FileStream_open_impl)
NativeDef(io_FileStream_out)
NativeDef(io_FileStream_pipe_impl)
NativeDef(io_FileStream_seek)
NativeDef(io_FileStream_stat_impl)
NativeDef(io_FileStream_tell)
NativeDef(io_FileStream_truncate)
NativeDef(io_Files_access)
NativeDef(io_Files_hardlink)
NativeDef(io_Files_lstat_impl)
NativeDef(io_Files_mkdir)
NativeDef(io_Files_readlink)
NativeDef(io_Files_remove)
NativeDef(io_Files_rename)
NativeDef(io_Files_stat_impl)
NativeDef(io_Files_symlink)
NativeDef(io_Files_truncate)
NativeDef(io_ProgStream_close)
NativeDef(io_ProgStream_open_impl)
NativeDef(io_RamStream_close)
NativeDef(io_RamStream_in)
NativeDef(io_RamStream_new_impl)
NativeDef(io_RamStream_out)
NativeDef(io_RamStream_seek)
NativeDef(io_RamStream_str)
NativeDef(io_RamStream_tell)
NativeDef(io_RamStream_truncate)
NativeDef(io_SocketStream_accept_impl)
NativeDef(io_SocketStream_bind)
NativeDef(io_SocketStream_close)
NativeDef(io_SocketStream_connect)
NativeDef(io_SocketStream_in)
NativeDef(io_SocketStream_listen)
NativeDef(io_SocketStream_out)
NativeDef(io_SocketStream_socket_impl)
NativeDef(io_SocketStream_socketpair_impl)
#if MSWIN32
NativeDef(io_WindowsFilePath_getdcwd)
NativeDef(io_WindowsFileSystem_get_roots)
#endif
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
NativeDef(lang_Class_load_library)
NativeDef(lang_Class_set_method)
NativeDef(parser_UReader_raw_convert)
NativeDef(util_Timezone_get_system_timezone)
