/*
 * List of native methods built-in to the runtime.  The first field is
 * the fully-qualified class name; the second is the field (method)
 * name.  The third field is the name of the implementing runtime
 * function, which should be in the form <class>_<field> with all dots
 * in <class> changed to underscores.
 * 
 * The entries must be grouped by class, but beyond that order is not
 * significant.
 */
#ifdef Graphics
NativeDef(graphics.Window,alert,graphics_Window_alert)
NativeDef(graphics.Window,can_resize,graphics_Window_can_resize)
NativeDef(graphics.Window,clip,graphics_Window_clip)
NativeDef(graphics.Window,clone_impl,graphics_Window_clone_impl)
NativeDef(graphics.Window,close,graphics_Window_close)
NativeDef(graphics.Window,color,graphics_Window_color)
NativeDef(graphics.Window,color_value,graphics_Window_color_value)
NativeDef(graphics.Window,copy_to,graphics_Window_copy_to)
NativeDef(graphics.Window,couple_impl,graphics_Window_couple_impl)
NativeDef(graphics.Window,draw_arc,graphics_Window_draw_arc)
NativeDef(graphics.Window,draw_circle,graphics_Window_draw_circle)
NativeDef(graphics.Window,draw_curve,graphics_Window_draw_curve)
NativeDef(graphics.Window,draw_image,graphics_Window_draw_image)
NativeDef(graphics.Window,draw_line,graphics_Window_draw_line)
NativeDef(graphics.Window,draw_point,graphics_Window_draw_point)
NativeDef(graphics.Window,draw_polygon,graphics_Window_draw_polygon)
NativeDef(graphics.Window,draw_rectangle,graphics_Window_draw_rectangle)
NativeDef(graphics.Window,draw_string,graphics_Window_draw_string)
NativeDef(graphics.Window,erase_area,graphics_Window_erase_area)
NativeDef(graphics.Window,event,graphics_Window_event)
NativeDef(graphics.Window,fill_arc,graphics_Window_fill_arc)
NativeDef(graphics.Window,fill_circle,graphics_Window_fill_circle)
NativeDef(graphics.Window,fill_polygon,graphics_Window_fill_polygon)
NativeDef(graphics.Window,fill_rectangle,graphics_Window_fill_rectangle)
NativeDef(graphics.Window,flush,graphics_Window_flush)
NativeDef(graphics.Window,free_color,graphics_Window_free_color)
NativeDef(graphics.Window,generic_color_value,graphics_Window_generic_color_value)
NativeDef(graphics.Window,generic_palette_key,graphics_Window_generic_palette_key)
NativeDef(graphics.Window,get_ascent,graphics_Window_get_ascent)
NativeDef(graphics.Window,get_bg,graphics_Window_get_bg)
NativeDef(graphics.Window,get_canvas,graphics_Window_get_canvas)
NativeDef(graphics.Window,get_cliph,graphics_Window_get_cliph)
NativeDef(graphics.Window,get_clipw,graphics_Window_get_clipw)
NativeDef(graphics.Window,get_clipx,graphics_Window_get_clipx)
NativeDef(graphics.Window,get_clipy,graphics_Window_get_clipy)
NativeDef(graphics.Window,get_depth,graphics_Window_get_depth)
NativeDef(graphics.Window,get_descent,graphics_Window_get_descent)
NativeDef(graphics.Window,get_display,graphics_Window_get_display)
NativeDef(graphics.Window,get_display_size,graphics_Window_get_display_size)
NativeDef(graphics.Window,get_drawop,graphics_Window_get_drawop)
NativeDef(graphics.Window,get_dx,graphics_Window_get_dx)
NativeDef(graphics.Window,get_dy,graphics_Window_get_dy)
NativeDef(graphics.Window,get_fg,graphics_Window_get_fg)
NativeDef(graphics.Window,get_fheight,graphics_Window_get_fheight)
NativeDef(graphics.Window,get_fillstyle,graphics_Window_get_fillstyle)
NativeDef(graphics.Window,get_font,graphics_Window_get_font)
NativeDef(graphics.Window,get_fwidth,graphics_Window_get_fwidth)
NativeDef(graphics.Window,get_gamma,graphics_Window_get_gamma)
NativeDef(graphics.Window,get_geometry,graphics_Window_get_geometry)
NativeDef(graphics.Window,get_height,graphics_Window_get_height)
NativeDef(graphics.Window,get_inputmask,graphics_Window_get_inputmask)
NativeDef(graphics.Window,get_label,graphics_Window_get_label)
NativeDef(graphics.Window,get_linestyle,graphics_Window_get_linestyle)
NativeDef(graphics.Window,get_linewidth,graphics_Window_get_linewidth)
NativeDef(graphics.Window,get_maxheight,graphics_Window_get_maxheight)
NativeDef(graphics.Window,get_maxsize,graphics_Window_get_maxsize)
NativeDef(graphics.Window,get_maxwidth,graphics_Window_get_maxwidth)
NativeDef(graphics.Window,get_minheight,graphics_Window_get_minheight)
NativeDef(graphics.Window,get_minsize,graphics_Window_get_minsize)
NativeDef(graphics.Window,get_minwidth,graphics_Window_get_minwidth)
NativeDef(graphics.Window,get_pattern,graphics_Window_get_pattern)
NativeDef(graphics.Window,get_pointer,graphics_Window_get_pointer)
NativeDef(graphics.Window,get_pos,graphics_Window_get_pos)
NativeDef(graphics.Window,get_posx,graphics_Window_get_posx)
NativeDef(graphics.Window,get_posy,graphics_Window_get_posy)
NativeDef(graphics.Window,get_size,graphics_Window_get_size)
NativeDef(graphics.Window,get_visual,graphics_Window_get_visual)
NativeDef(graphics.Window,get_width,graphics_Window_get_width)
NativeDef(graphics.Window,lower,graphics_Window_lower)
NativeDef(graphics.Window,new_color,graphics_Window_new_color)
NativeDef(graphics.Window,own_selection,graphics_Window_own_selection)
NativeDef(graphics.Window,palette_chars,graphics_Window_palette_chars)
NativeDef(graphics.Window,palette_color,graphics_Window_palette_color)
NativeDef(graphics.Window,palette_key,graphics_Window_palette_key)
NativeDef(graphics.Window,pending,graphics_Window_pending)
NativeDef(graphics.Window,pixel,graphics_Window_pixel)
NativeDef(graphics.Window,post_attrib,graphics_Window_post_attrib)
NativeDef(graphics.Window,post_set,graphics_Window_post_set)
NativeDef(graphics.Window,pre_attrib,graphics_Window_pre_attrib)
NativeDef(graphics.Window,query_pointer,graphics_Window_query_pointer)
NativeDef(graphics.Window,query_root_pointer,graphics_Window_query_root_pointer)
NativeDef(graphics.Window,raise,graphics_Window_raise)
NativeDef(graphics.Window,read_image,graphics_Window_read_image)
NativeDef(graphics.Window,request_selection,graphics_Window_request_selection)
NativeDef(graphics.Window,send_selection_response,graphics_Window_send_selection_response)
NativeDef(graphics.Window,set_bg,graphics_Window_set_bg)
NativeDef(graphics.Window,set_canvas,graphics_Window_set_canvas)
NativeDef(graphics.Window,set_cliph,graphics_Window_set_cliph)
NativeDef(graphics.Window,set_clipw,graphics_Window_set_clipw)
NativeDef(graphics.Window,set_clipx,graphics_Window_set_clipx)
NativeDef(graphics.Window,set_clipy,graphics_Window_set_clipy)
NativeDef(graphics.Window,set_drawop,graphics_Window_set_drawop)
NativeDef(graphics.Window,set_dx,graphics_Window_set_dx)
NativeDef(graphics.Window,set_dy,graphics_Window_set_dy)
NativeDef(graphics.Window,set_fg,graphics_Window_set_fg)
NativeDef(graphics.Window,set_fillstyle,graphics_Window_set_fillstyle)
NativeDef(graphics.Window,set_font,graphics_Window_set_font)
NativeDef(graphics.Window,set_gamma,graphics_Window_set_gamma)
NativeDef(graphics.Window,set_geometry,graphics_Window_set_geometry)
NativeDef(graphics.Window,set_height,graphics_Window_set_height)
NativeDef(graphics.Window,set_image,graphics_Window_set_image)
NativeDef(graphics.Window,set_inputmask,graphics_Window_set_inputmask)
NativeDef(graphics.Window,set_label,graphics_Window_set_label)
NativeDef(graphics.Window,set_linestyle,graphics_Window_set_linestyle)
NativeDef(graphics.Window,set_linewidth,graphics_Window_set_linewidth)
NativeDef(graphics.Window,set_maxheight,graphics_Window_set_maxheight)
NativeDef(graphics.Window,set_maxsize,graphics_Window_set_maxsize)
NativeDef(graphics.Window,set_maxwidth,graphics_Window_set_maxwidth)
NativeDef(graphics.Window,set_minheight,graphics_Window_set_minheight)
NativeDef(graphics.Window,set_minsize,graphics_Window_set_minsize)
NativeDef(graphics.Window,set_minwidth,graphics_Window_set_minwidth)
NativeDef(graphics.Window,set_pattern,graphics_Window_set_pattern)
NativeDef(graphics.Window,set_pointer,graphics_Window_set_pointer)
NativeDef(graphics.Window,set_pos,graphics_Window_set_pos)
NativeDef(graphics.Window,set_posx,graphics_Window_set_posx)
NativeDef(graphics.Window,set_posy,graphics_Window_set_posy)
NativeDef(graphics.Window,set_resize,graphics_Window_set_resize)
NativeDef(graphics.Window,set_size,graphics_Window_set_size)
NativeDef(graphics.Window,set_titlebar,graphics_Window_set_titlebar)
NativeDef(graphics.Window,set_width,graphics_Window_set_width)
NativeDef(graphics.Window,sync,graphics_Window_sync)
NativeDef(graphics.Window,text_width,graphics_Window_text_width)
NativeDef(graphics.Window,toggle_fgbg,graphics_Window_toggle_fgbg)
NativeDef(graphics.Window,unclip,graphics_Window_unclip)
NativeDef(graphics.Window,uncouple,graphics_Window_uncouple)
NativeDef(graphics.Window,warp_pointer,graphics_Window_warp_pointer)
NativeDef(graphics.Window,wcreate,graphics_Window_wcreate)
NativeDef(graphics.Window,wdefault,graphics_Window_wdefault)
NativeDef(graphics.Window,wopen,graphics_Window_wopen)
NativeDef(graphics.Window,write_image,graphics_Window_write_image)
#else
NativeDef(graphics.Window,open_impl,graphics_Window_open_impl)
#endif
NativeDef(io.DescStream,flag,io_DescStream_flag)
NativeDef(io.DescStream,poll,io_DescStream_poll)
NativeDef(io.DescStream,select,io_DescStream_select)
NativeDef(io.DescStream,stat_impl,io_DescStream_stat_impl)
NativeDef(io.DescStream,dup2_impl,io_DescStream_dup2_impl)
NativeDef(io.DirStream,close,io_DirStream_close)
NativeDef(io.DirStream,open_impl,io_DirStream_open_impl)
NativeDef(io.DirStream,read_impl,io_DirStream_read_impl)
NativeDef(io.FileStream,close,io_FileStream_close)
NativeDef(io.FileStream,in,io_FileStream_in)
NativeDef(io.FileStream,open_impl,io_FileStream_open_impl)
NativeDef(io.FileStream,out,io_FileStream_out)
NativeDef(io.FileStream,pipe_impl,io_FileStream_pipe_impl)
NativeDef(io.FileStream,seek,io_FileStream_seek)
NativeDef(io.FileStream,tell,io_FileStream_tell)
NativeDef(io.FileStream,truncate,io_FileStream_truncate)
NativeDef(io.FileStream,chdir,io_FileStream_chdir)
NativeDef(io.Files,access,io_Files_access)
NativeDef(io.Files,hardlink,io_Files_hardlink)
#if PLAN9
NativeDef(io.Files,list_impl,io_Files_list_impl)
#endif
NativeDef(io.Files,lstat_impl,io_Files_lstat_impl)
NativeDef(io.Files,mkdir,io_Files_mkdir)
NativeDef(io.Files,rmdir,io_Files_rmdir)
NativeDef(io.Files,chdir,io_Files_chdir)
NativeDef(io.Files,getcwd,io_Files_getcwd)
NativeDef(io.Files,readlink,io_Files_readlink)
NativeDef(io.Files,remove,io_Files_remove)
NativeDef(io.Files,rename,io_Files_rename)
NativeDef(io.Files,stat_impl,io_Files_stat_impl)
NativeDef(io.Files,symlink,io_Files_symlink)
NativeDef(io.Files,truncate,io_Files_truncate)
NativeDef(io.RamStream,close,io_RamStream_close)
NativeDef(io.RamStream,in,io_RamStream_in)
NativeDef(io.RamStream,new_impl,io_RamStream_new_impl)
NativeDef(io.RamStream,out,io_RamStream_out)
NativeDef(io.RamStream,seek,io_RamStream_seek)
NativeDef(io.RamStream,str,io_RamStream_str)
NativeDef(io.RamStream,tell,io_RamStream_tell)
NativeDef(io.RamStream,truncate,io_RamStream_truncate)
NativeDef(io.SocketStream,accept_impl,io_SocketStream_accept_impl)
NativeDef(io.SocketStream,bind,io_SocketStream_bind)
NativeDef(io.SocketStream,close,io_SocketStream_close)
NativeDef(io.SocketStream,connect,io_SocketStream_connect)
NativeDef(io.SocketStream,in,io_SocketStream_in)
NativeDef(io.SocketStream,listen,io_SocketStream_listen)
NativeDef(io.SocketStream,out,io_SocketStream_out)
NativeDef(io.SocketStream,socket_impl,io_SocketStream_socket_impl)
NativeDef(io.SocketStream,socketpair_impl,io_SocketStream_socketpair_impl)
#if MSWIN32
NativeDef(io.WindowsFilePath,getdcwd,io_WindowsFilePath_getdcwd)
NativeDef(io.WindowsFileSystem,get_roots,io_WindowsFileSystem_get_roots)
#endif
NativeDef(io.Keyboard,getch,io_Keyboard_getch)
NativeDef(io.Keyboard,getche,io_Keyboard_getche)
NativeDef(io.Keyboard,kbhit,io_Keyboard_kbhit)
NativeDef(lang.Class,complete_raw,lang_Class_complete_raw)
NativeDef(lang.Class,create_raw,lang_Class_create_raw)
NativeDef(lang.Class,ensure_initialized,lang_Class_ensure_initialized)
NativeDef(lang.Class,get,lang_Class_get)
NativeDef(lang.Class,get_cast_class,lang_Class_get_cast_class)
NativeDef(lang.Class,get_cast_object,lang_Class_get_cast_object)
NativeDef(lang.Class,get_class_field_names,lang_Class_get_class_field_names)
NativeDef(lang.Class,get_class_flags,lang_Class_get_class_flags)
NativeDef(lang.Class,get_field_defining_class,lang_Class_get_field_defining_class)
NativeDef(lang.Class,get_field_flags,lang_Class_get_field_flags)
NativeDef(lang.Class,get_field_index,lang_Class_get_field_index)
NativeDef(lang.Class,get_field_location_impl,lang_Class_get_field_location_impl)
NativeDef(lang.Class,get_field_name,lang_Class_get_field_name)
NativeDef(lang.Class,get_field_names,lang_Class_get_field_names)
NativeDef(lang.Class,get_implemented_classes,lang_Class_get_implemented_classes)
NativeDef(lang.Class,get_instance_field_names,lang_Class_get_instance_field_names)
NativeDef(lang.Class,get_location_impl,lang_Class_get_location_impl)
NativeDef(lang.Class,get_methp_object,lang_Class_get_methp_object)
NativeDef(lang.Class,get_methp_proc,lang_Class_get_methp_proc)
NativeDef(lang.Class,get_n_class_fields,lang_Class_get_n_class_fields)
NativeDef(lang.Class,get_n_fields,lang_Class_get_n_fields)
NativeDef(lang.Class,get_n_instance_fields,lang_Class_get_n_instance_fields)
NativeDef(lang.Class,get_name,lang_Class_get_name)
NativeDef(lang.Class,get_class,lang_Class_get_class)
NativeDef(lang.Class,get_package,lang_Class_get_package)
NativeDef(lang.Class,get_program,lang_Class_get_program)
NativeDef(lang.Class,get_supers,lang_Class_get_supers)
NativeDef(lang.Class,getf,lang_Class_getf)
NativeDef(lang.Class,getq,lang_Class_getq)
NativeDef(lang.Class,implements,lang_Class_implements)
NativeDef(lang.Class,load_library,lang_Class_load_library)
NativeDef(lang.Class,set_method,lang_Class_set_method)
NativeDef(lang.Constructor,get_field_index,lang_Constructor_get_field_index)
NativeDef(lang.Constructor,get_field_location_impl,lang_Constructor_get_field_location_impl)
NativeDef(lang.Constructor,get_field_name,lang_Constructor_get_field_name)
NativeDef(lang.Constructor,get_field_names,lang_Constructor_get_field_names)
NativeDef(lang.Constructor,get_location_impl,lang_Constructor_get_location_impl)
NativeDef(lang.Constructor,get_n_fields,lang_Constructor_get_n_fields)
NativeDef(lang.Constructor,get_name,lang_Constructor_get_name)
NativeDef(lang.Constructor,get_constructor,lang_Constructor_get_constructor)
NativeDef(lang.Constructor,get_package,lang_Constructor_get_package)
NativeDef(lang.Constructor,get_program,lang_Constructor_get_program)
NativeDef(lang.Internal,compare,lang_Internal_compare)
NativeDef(lang.Internal,hash,lang_Internal_hash)
NativeDef(lang.Proc,get_defining_class,lang_Proc_get_defining_class)
NativeDef(lang.Proc,get_field_name,lang_Proc_get_field_name)
NativeDef(lang.Proc,get_kind,lang_Proc_get_kind)
NativeDef(lang.Proc,get_local_index,lang_Proc_get_local_index)
NativeDef(lang.Proc,get_local_location_impl,lang_Proc_get_local_location_impl)
NativeDef(lang.Proc,get_local_name,lang_Proc_get_local_name)
NativeDef(lang.Proc,get_local_names,lang_Proc_get_local_names)
NativeDef(lang.Proc,get_local_kind,lang_Proc_get_local_kind)
NativeDef(lang.Proc,get_location_impl,lang_Proc_get_location_impl)
NativeDef(lang.Proc,get_n_arguments,lang_Proc_get_n_arguments)
NativeDef(lang.Proc,get_n_dynamics,lang_Proc_get_n_dynamics)
NativeDef(lang.Proc,get_n_locals,lang_Proc_get_n_locals)
NativeDef(lang.Proc,get_n_statics,lang_Proc_get_n_statics)
NativeDef(lang.Proc,get_name,lang_Proc_get_name)
NativeDef(lang.Proc,get_package,lang_Proc_get_package)
NativeDef(lang.Proc,get_program,lang_Proc_get_program)
NativeDef(lang.Proc,has_varargs,lang_Proc_has_varargs)
NativeDef(lang.Proc,is_defined,lang_Proc_is_defined)
NativeDef(lang.Proc,load,lang_Proc_load)
NativeDef(lang.Coexpression,get_activator,lang_Coexpression_get_activator)
NativeDef(lang.Coexpression,get_level,lang_Coexpression_get_level)
NativeDef(lang.Coexpression,get_program,lang_Coexpression_get_program)
NativeDef(lang.Coexpression,get_stack_info_impl,lang_Coexpression_get_stack_info_impl)
NativeDef(lang.Coexpression,is_main,lang_Coexpression_is_main)
NativeDef(lang.Coexpression,traceback,lang_Coexpression_traceback)
NativeDef(lang.Prog,get_global,lang_Prog_get_global)
NativeDef(lang.Prog,get_globals,lang_Prog_get_globals)
NativeDef(lang.Prog,get_global_names,lang_Prog_get_global_names)
NativeDef(lang.Prog,get_functions,lang_Prog_get_functions)
NativeDef(lang.Prog,get_keywords,lang_Prog_get_keywords)
NativeDef(lang.Prog,get_operators,lang_Prog_get_operators)
NativeDef(lang.Prog,get_function,lang_Prog_get_function)
NativeDef(lang.Prog,get_keyword,lang_Prog_get_keyword)
NativeDef(lang.Prog,get_operator,lang_Prog_get_operator)
NativeDef(lang.Prog,get_global_location_impl,lang_Prog_get_global_location_impl)
NativeDef(lang.Prog,eval_keyword,lang_Prog_eval_keyword)
NativeDef(lang.Prog,get_variable,lang_Prog_get_variable)
NativeDef(lang.Prog,get_variable_name,lang_Prog_get_variable_name)
NativeDef(lang.Prog,load,lang_Prog_load)
NativeDef(lang.Prog,get_event_mask,lang_Prog_get_event_mask)
NativeDef(lang.Prog,set_event_mask,lang_Prog_set_event_mask)
NativeDef(lang.Prog,get_event_impl,lang_Prog_get_event_impl)
NativeDef(lang.Prog,get_runtime_millis,lang_Prog_get_runtime_millis)
NativeDef(lang.Prog,get_startup_micros,lang_Prog_get_startup_micros)
NativeDef(lang.Prog,get_collection_info_impl,lang_Prog_get_collection_info_impl)
NativeDef(lang.Prog,get_allocation_info_impl,lang_Prog_get_allocation_info_impl)
NativeDef(lang.Prog,get_region_info_impl,lang_Prog_get_region_info_impl)
NativeDef(lang.Prog,get_stack_used,lang_Prog_get_stack_used)
NativeDef(lang.Text,get_ord_range,lang_Text_get_ord_range)
NativeDef(lang.Text,create_cset,lang_Text_create_cset)
NativeDef(lang.Text,has_ord,lang_Text_has_ord)
NativeDef(lang.Text,utf8_seq,lang_Text_utf8_seq)
NativeDef(lang.Text,slice,lang_Text_slice)
NativeDef(parser.UReader,raw_convert,parser_UReader_raw_convert)
NativeDef(util.Connectable,is_methp_with_object,util_Connectable_is_methp_with_object)
NativeDef(util.Timezone,get_system_timezone,util_Timezone_get_system_timezone)
NativeDef(util.Time,get_system_seconds,util_Time_get_system_seconds)
NativeDef(util.Time,get_system_millis,util_Time_get_system_millis)
NativeDef(util.Time,get_system_micros,util_Time_get_system_micros)
NativeDef(posix.System,execve,posix_System_execve)
NativeDef(posix.System,environ,posix_System_environ)
NativeDef(posix.System,fork,posix_System_fork)
NativeDef(posix.System,kill,posix_System_kill)
NativeDef(posix.System,wait,posix_System_wait)
NativeDef(posix.System,getenv,posix_System_getenv)
NativeDef(posix.System,setenv,posix_System_setenv)
NativeDef(posix.System,unsetenv,posix_System_unsetenv)
NativeDef(posix.System,uname_impl,posix_System_uname_impl)
NativeDef(util.Math,acos,util_Math_acos)
NativeDef(util.Math,asin,util_Math_asin)
NativeDef(util.Math,atan,util_Math_atan)
NativeDef(util.Math,cos,util_Math_cos)
NativeDef(util.Math,dtor,util_Math_dtor)
NativeDef(util.Math,rtod,util_Math_rtod)
NativeDef(util.Math,tan,util_Math_tan)
NativeDef(util.Math,exp,util_Math_exp)
NativeDef(util.Math,log,util_Math_log)
NativeDef(util.Math,sin,util_Math_sin)
NativeDef(util.Math,sqrt,util_Math_sqrt)
