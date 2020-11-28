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
NativeDef(graphics.Window,new_impl,graphics_Window_new_impl)
NativeDef(graphics.Window,color_value,graphics_Window_color_value)
NativeDef(graphics.Window,parse_color_impl,graphics_Window_parse_color_impl)
NativeDef(graphics.Window,palette_chars,graphics_Window_palette_chars)
NativeDef(graphics.Window,palette_color,graphics_Window_palette_color)
NativeDef(graphics.Window,palette_key,graphics_Window_palette_key)
NativeDef(graphics.Window,get_default_font,graphics_Window_get_default_font)
NativeDef(graphics.Window,get_default_font_size,graphics_Window_get_default_font_size)
NativeDef(graphics.Window,get_default_leading,graphics_Window_get_default_leading)
#if Graphics
NativeDef(graphics.Window,alert,graphics_Window_alert)
NativeDef(graphics.Window,can_resize,graphics_Window_can_resize)
NativeDef(graphics.Window,clip,graphics_Window_clip)
NativeDef(graphics.Window,clone_impl,graphics_Window_clone_impl)
NativeDef(graphics.Window,close,graphics_Window_close)
NativeDef(graphics.Window,copy_to,graphics_Window_copy_to)
NativeDef(graphics.Window,couple_impl,graphics_Window_couple_impl)
NativeDef(graphics.Window,drawable_impl,graphics_Window_drawable_impl)
NativeDef(graphics.Window,viewable_impl,graphics_Window_viewable_impl)
NativeDef(graphics.Window,draw_arc,graphics_Window_draw_arc)
NativeDef(graphics.Window,draw_curve,graphics_Window_draw_curve)
NativeDef(graphics.Window,draw_image_impl,graphics_Window_draw_image_impl)
NativeDef(graphics.Window,draw_line,graphics_Window_draw_line)
NativeDef(graphics.Window,draw_rectangle,graphics_Window_draw_rectangle)
NativeDef(graphics.Window,draw_string,graphics_Window_draw_string)
NativeDef(graphics.Window,erase_area,graphics_Window_erase_area)
NativeDef(graphics.Window,event,graphics_Window_event)
NativeDef(graphics.Window,hold,graphics_Window_hold)
NativeDef(graphics.Window,restore,graphics_Window_restore)
NativeDef(graphics.Window,fill_arc,graphics_Window_fill_arc)
NativeDef(graphics.Window,fill_polygon,graphics_Window_fill_polygon)
NativeDef(graphics.Window,fill_triangles,graphics_Window_fill_triangles)
NativeDef(graphics.Window,fill_rectangle,graphics_Window_fill_rectangle)
NativeDef(graphics.Window,filter,graphics_Window_filter)
NativeDef(graphics.Window,get_font_ascent,graphics_Window_get_font_ascent)
NativeDef(graphics.Window,get_bg,graphics_Window_get_bg)
NativeDef(graphics.Window,get_canvas,graphics_Window_get_canvas)
NativeDef(graphics.Window,get_clip_impl,graphics_Window_get_clip_impl)
NativeDef(graphics.Window,get_depth,graphics_Window_get_depth)
NativeDef(graphics.Window,get_font_descent,graphics_Window_get_font_descent)
NativeDef(graphics.Window,get_format,graphics_Window_get_format)
NativeDef(graphics.Window,get_id,graphics_Window_get_id)
NativeDef(graphics.Window,get_fd,graphics_Window_get_fd)
NativeDef(graphics.Window,get_display,graphics_Window_get_display)
NativeDef(graphics.Window,get_display_size_impl,graphics_Window_get_display_size_impl)
NativeDef(graphics.Window,get_display_size_mm_impl,graphics_Window_get_display_size_mm_impl)
NativeDef(graphics.Window,get_draw_op,graphics_Window_get_draw_op)
NativeDef(graphics.Window,get_dx,graphics_Window_get_dx)
NativeDef(graphics.Window,get_dy,graphics_Window_get_dy)
NativeDef(graphics.Window,get_absolute_leading,graphics_Window_get_absolute_leading)
NativeDef(graphics.Window,get_leading,graphics_Window_get_leading)
NativeDef(graphics.Window,get_fg,graphics_Window_get_fg)
NativeDef(graphics.Window,get_font,graphics_Window_get_font)
NativeDef(graphics.Window,get_font_width,graphics_Window_get_font_width)
NativeDef(graphics.Window,get_height,graphics_Window_get_height)
NativeDef(graphics.Window,get_label,graphics_Window_get_label)
NativeDef(graphics.Window,get_line_end,graphics_Window_get_line_end)
NativeDef(graphics.Window,get_line_join,graphics_Window_get_line_join)
NativeDef(graphics.Window,get_line_width,graphics_Window_get_line_width)
NativeDef(graphics.Window,get_fill_rule,graphics_Window_get_fill_rule)
NativeDef(graphics.Window,get_max_height,graphics_Window_get_max_height)
NativeDef(graphics.Window,get_max_width,graphics_Window_get_max_width)
NativeDef(graphics.Window,get_min_height,graphics_Window_get_min_height)
NativeDef(graphics.Window,get_min_width,graphics_Window_get_min_width)
NativeDef(graphics.Window,get_pixels_impl,graphics_Window_get_pixels_impl)
NativeDef(graphics.Window,get_pointer,graphics_Window_get_pointer)
NativeDef(graphics.Window,get_x,graphics_Window_get_x)
NativeDef(graphics.Window,get_y,graphics_Window_get_y)
NativeDef(graphics.Window,get_width,graphics_Window_get_width)
NativeDef(graphics.Window,get_references_impl,graphics_Window_get_references_impl)
NativeDef(graphics.Window,grab_pointer,graphics_Window_grab_pointer)
NativeDef(graphics.Window,ungrab_pointer,graphics_Window_ungrab_pointer)
NativeDef(graphics.Window,grab_keyboard,graphics_Window_grab_keyboard)
NativeDef(graphics.Window,ungrab_keyboard,graphics_Window_ungrab_keyboard)
NativeDef(graphics.Window,lower,graphics_Window_lower)
NativeDef(graphics.Window,focus,graphics_Window_focus)
NativeDef(graphics.Window,own_selection,graphics_Window_own_selection)
NativeDef(graphics.Window,pending,graphics_Window_pending)
NativeDef(graphics.Window,peek,graphics_Window_peek)
NativeDef(graphics.Window,query_pointer_impl,graphics_Window_query_pointer_impl)
NativeDef(graphics.Window,query_root_pointer_impl,graphics_Window_query_root_pointer_impl)
NativeDef(graphics.Window,raise,graphics_Window_raise)
NativeDef(graphics.Window,request_selection,graphics_Window_request_selection)
NativeDef(graphics.Window,send_selection_response,graphics_Window_send_selection_response)
NativeDef(graphics.Window,set_bg,graphics_Window_set_bg)
NativeDef(graphics.Window,set_canvas,graphics_Window_set_canvas)
NativeDef(graphics.Window,set_draw_op,graphics_Window_set_draw_op)
NativeDef(graphics.Window,set_dx,graphics_Window_set_dx)
NativeDef(graphics.Window,set_dy,graphics_Window_set_dy)
NativeDef(graphics.Window,set_leading,graphics_Window_set_leading)
NativeDef(graphics.Window,set_fg,graphics_Window_set_fg)
NativeDef(graphics.Window,set_pattern_impl,graphics_Window_set_pattern_impl)
NativeDef(graphics.Window,set_mask_impl,graphics_Window_set_mask_impl)
NativeDef(graphics.Window,set_font,graphics_Window_set_font)
NativeDef(graphics.Window,set_geometry,graphics_Window_set_geometry)
NativeDef(graphics.Window,set_height,graphics_Window_set_height)
NativeDef(graphics.Window,set_icon_impl,graphics_Window_set_icon_impl)
NativeDef(graphics.Window,set_label,graphics_Window_set_label)
NativeDef(graphics.Window,set_line_end,graphics_Window_set_line_end)
NativeDef(graphics.Window,set_line_join,graphics_Window_set_line_join)
NativeDef(graphics.Window,set_line_width,graphics_Window_set_line_width)
NativeDef(graphics.Window,set_fill_rule,graphics_Window_set_fill_rule)
NativeDef(graphics.Window,set_max_height,graphics_Window_set_max_height)
NativeDef(graphics.Window,set_max_size,graphics_Window_set_max_size)
NativeDef(graphics.Window,set_max_width,graphics_Window_set_max_width)
NativeDef(graphics.Window,set_min_height,graphics_Window_set_min_height)
NativeDef(graphics.Window,set_min_size,graphics_Window_set_min_size)
NativeDef(graphics.Window,set_min_width,graphics_Window_set_min_width)
NativeDef(graphics.Window,set_increment_height,graphics_Window_set_increment_height)
NativeDef(graphics.Window,set_increment_size,graphics_Window_set_increment_size)
NativeDef(graphics.Window,set_increment_width,graphics_Window_set_increment_width)
NativeDef(graphics.Window,set_base_height,graphics_Window_set_base_height)
NativeDef(graphics.Window,set_base_size,graphics_Window_set_base_size)
NativeDef(graphics.Window,set_base_width,graphics_Window_set_base_width)
NativeDef(graphics.Window,get_increment_height,graphics_Window_get_increment_height)
NativeDef(graphics.Window,get_increment_width,graphics_Window_get_increment_width)
NativeDef(graphics.Window,get_base_height,graphics_Window_get_base_height)
NativeDef(graphics.Window,get_base_width,graphics_Window_get_base_width)
NativeDef(graphics.Window,set_max_aspect_ratio,graphics_Window_set_max_aspect_ratio)
NativeDef(graphics.Window,get_max_aspect_ratio,graphics_Window_get_max_aspect_ratio)
NativeDef(graphics.Window,set_min_aspect_ratio,graphics_Window_set_min_aspect_ratio)
NativeDef(graphics.Window,get_min_aspect_ratio,graphics_Window_get_min_aspect_ratio)
NativeDef(graphics.Window,set_transient_for,graphics_Window_set_transient_for)
NativeDef(graphics.Window,set_pointer,graphics_Window_set_pointer)
NativeDef(graphics.Window,set_pos,graphics_Window_set_pos)
NativeDef(graphics.Window,set_x,graphics_Window_set_x)
NativeDef(graphics.Window,set_y,graphics_Window_set_y)
NativeDef(graphics.Window,set_resize,graphics_Window_set_resize)
NativeDef(graphics.Window,set_size,graphics_Window_set_size)
NativeDef(graphics.Window,set_width,graphics_Window_set_width)
NativeDef(graphics.Window,text_width,graphics_Window_text_width)
NativeDef(graphics.Window,unclip,graphics_Window_unclip)
NativeDef(graphics.Window,warp_pointer,graphics_Window_warp_pointer)
NativeDef(graphics.Window,define_pointer_impl,graphics_Window_define_pointer_impl)
NativeDef(graphics.Window,copy_pointer,graphics_Window_copy_pointer)
#endif /* Graphics */
NativeDef(graphics.Pixels,get_width,graphics_Pixels_get_width)
NativeDef(graphics.Pixels,get_height,graphics_Pixels_get_height)
NativeDef(graphics.Pixels,close,graphics_Pixels_close)
NativeDef(graphics.Pixels,get,graphics_Pixels_get)
NativeDef(graphics.Pixels,set,graphics_Pixels_set)
NativeDef(graphics.Pixels,get_rgba_impl,graphics_Pixels_get_rgba_impl)
NativeDef(graphics.Pixels,set_rgba,graphics_Pixels_set_rgba)
NativeDef(graphics.Pixels,copy_pixel,graphics_Pixels_copy_pixel)
NativeDef(graphics.Pixels,copy_to,graphics_Pixels_copy_to)
NativeDef(graphics.Pixels,scale_to,graphics_Pixels_scale_to)
NativeDef(graphics.Pixels,get_data,graphics_Pixels_get_data)
NativeDef(graphics.Pixels,set_data,graphics_Pixels_set_data)
NativeDef(graphics.Pixels,new_open_impl,graphics_Pixels_new_open_impl)
NativeDef(graphics.Pixels,get_format,graphics_Pixels_get_format)
NativeDef(graphics.Pixels,gen_rgba_impl,graphics_Pixels_gen_rgba_impl)
NativeDef(graphics.Pixels,gen_impl,graphics_Pixels_gen_impl)
NativeDef(graphics.Pixels,new_blank_impl,graphics_Pixels_new_blank_impl)
NativeDef(graphics.Pixels,get_palette_size,graphics_Pixels_get_palette_size)
NativeDef(graphics.Pixels,get_palette_rgba_impl,graphics_Pixels_get_palette_rgba_impl)
NativeDef(graphics.Pixels,set_palette_rgba,graphics_Pixels_set_palette_rgba)
NativeDef(graphics.Pixels,get_palette,graphics_Pixels_get_palette)
NativeDef(graphics.Pixels,set_palette,graphics_Pixels_set_palette)
NativeDef(graphics.Pixels,get_palette_index,graphics_Pixels_get_palette_index)
NativeDef(graphics.Pixels,set_palette_index,graphics_Pixels_set_palette_index)
NativeDef(graphics.Pixels,load_palette,graphics_Pixels_load_palette)
NativeDef(graphics.Pixels,to_file,graphics_Pixels_to_file)
NativeDef(graphics.Pixels,clone_impl,graphics_Pixels_clone_impl)
NativeDef(graphics.Pixels,convert_impl,graphics_Pixels_convert_impl)
NativeDef(graphics.Pixels,shared_copy_impl,graphics_Pixels_shared_copy_impl)
NativeDef(graphics.Pixels,get_references,graphics_Pixels_get_references)
NativeDef(graphics.Pixels,get_alpha_depth,graphics_Pixels_get_alpha_depth)
NativeDef(graphics.Pixels,get_color_depth,graphics_Pixels_get_color_depth)
NativeDef(io.DescStream,flag,io_DescStream_flag)
NativeDef(io.DescStream,dflag,io_DescStream_dflag)
#if !PLAN9
NativeDef(io.DescStream,poll,io_DescStream_poll)
#endif
NativeDef(io.DescStream,stat_impl,io_DescStream_stat_impl)
NativeDef(io.DescStream,dup2_impl,io_DescStream_dup2_impl)
NativeDef(io.DescStream,dup_impl,io_DescStream_dup_impl)
NativeDef(io.DescStream,wstat,io_DescStream_wstat)
NativeDef(io.DirStream,close,io_DirStream_close)
NativeDef(io.DirStream,new_impl,io_DirStream_new_impl)
NativeDef(io.DirStream,read_line_impl,io_DirStream_read_line_impl)
NativeDef(io.FileStream,close,io_FileStream_close)
NativeDef(io.FileStream,in,io_FileStream_in)
#if PLAN9
NativeDef(io.FileStream,create_impl,io_FileStream_create_impl)
NativeDef(io.FileStream,open_impl,io_FileStream_open_impl)
NativeDef(io.FileStream,fd2path,io_FileStream_fd2path)
#else
NativeDef(io.FileStream,new_impl,io_FileStream_new_impl)
#endif
NativeDef(io.FileStream,out,io_FileStream_out)
NativeDef(io.FileStream,pipe_impl,io_FileStream_pipe_impl)
NativeDef(io.FileStream,seek,io_FileStream_seek)
NativeDef(io.FileStream,tell,io_FileStream_tell)
NativeDef(io.FileStream,truncate,io_FileStream_truncate)
NativeDef(io.FileStream,chdir,io_FileStream_chdir)
NativeDef(io.FileStream,ttyname,io_FileStream_ttyname)
NativeDef(io.FileStream,isatty,io_FileStream_isatty)
NativeDef(io.FileStream,pread,io_FileStream_pread)
NativeDef(io.FileStream,pwrite,io_FileStream_pwrite)
NativeDef(io.Files,access,io_Files_access)
NativeDef(io.Files,hardlink,io_Files_hardlink)
#if PLAN9
NativeDef(io.Files,dir_read_impl,io_Files_dir_read_impl)
NativeDef(io.Files,mount,io_Files_mount)
NativeDef(io.Files,bind,io_Files_bind)
NativeDef(io.Files,unmount,io_Files_unmount)
#endif
NativeDef(io.Files,lstat_impl,io_Files_lstat_impl)
NativeDef(io.Files,mkdir,io_Files_mkdir)
NativeDef(io.Files,rmdir,io_Files_rmdir)
NativeDef(io.Files,chdir,io_Files_chdir)
#if !PLAN9
NativeDef(io.Files,getcwd,io_Files_getcwd)
#endif
NativeDef(io.Files,readlink,io_Files_readlink)
NativeDef(io.Files,realpath,io_Files_realpath)
NativeDef(io.Files,remove,io_Files_remove)
NativeDef(io.Files,rename,io_Files_rename)
NativeDef(io.Files,stat_impl,io_Files_stat_impl)
NativeDef(io.Files,symlink,io_Files_symlink)
NativeDef(io.Files,truncate,io_Files_truncate)
NativeDef(io.Files,wstat,io_Files_wstat)
NativeDef(io.Files,bulk_close,io_Files_bulk_close)
NativeDef(io.RamStream,close,io_RamStream_close)
NativeDef(io.RamStream,in,io_RamStream_in)
NativeDef(io.RamStream,new_impl,io_RamStream_new_impl)
NativeDef(io.RamStream,out,io_RamStream_out)
NativeDef(io.RamStream,read_line,io_RamStream_read_line)
NativeDef(io.RamStream,seek,io_RamStream_seek)
NativeDef(io.RamStream,str,io_RamStream_str)
NativeDef(io.RamStream,tell,io_RamStream_tell)
NativeDef(io.RamStream,truncate,io_RamStream_truncate)
#if UNIX
NativeDef(io.PipeStream,out,io_PipeStream_out)
NativeDef(io.SocketStream,accept_impl,io_SocketStream_accept_impl)
NativeDef(io.SocketStream,bind,io_SocketStream_bind)
NativeDef(io.SocketStream,close,io_SocketStream_close)
NativeDef(io.SocketStream,connect,io_SocketStream_connect)
NativeDef(io.SocketStream,dns_query,io_SocketStream_dns_query)
NativeDef(io.SocketStream,in,io_SocketStream_in)
NativeDef(io.SocketStream,listen,io_SocketStream_listen)
NativeDef(io.SocketStream,get_peer,io_SocketStream_get_peer)
NativeDef(io.SocketStream,get_local,io_SocketStream_get_local)
NativeDef(io.SocketStream,out,io_SocketStream_out)
NativeDef(io.SocketStream,shutdown,io_SocketStream_shutdown)
NativeDef(io.SocketStream,new_impl,io_SocketStream_new_impl)
NativeDef(io.SocketStream,socketpair_impl,io_SocketStream_socketpair_impl)
NativeDef(io.SocketStream,sendto,io_SocketStream_sendto)
NativeDef(io.SocketStream,recvfrom_impl,io_SocketStream_recvfrom_impl)
NativeDef(io.SocketStream,setopt,io_SocketStream_setopt)
NativeDef(io.SocketStream,getopt,io_SocketStream_getopt)
#else
NativeDef(io.SocketStream,new_impl,io_SocketStream_new_impl)
NativeDef(io.SocketStream,socketpair_impl,io_SocketStream_socketpair_impl)
NativeDef(io.SocketStream,dns_query,io_SocketStream_dns_query)
#endif
#if PLAN9
NativeDef(io.PipeStream,out,io_PipeStream_out)
NativeDef(io.FileWorker,new_impl,io_FileWorker_new_impl)
NativeDef(io.FileWorker,op_read,io_FileWorker_op_read)
NativeDef(io.FileWorker,op_write,io_FileWorker_op_write)
NativeDef(io.FileWorker,op_write_all,io_FileWorker_op_write_all)
NativeDef(io.FileWorker,op_pread,io_FileWorker_op_pread)
NativeDef(io.FileWorker,op_pwrite,io_FileWorker_op_pwrite)
NativeDef(io.FileWorker,op_open,io_FileWorker_op_open)
NativeDef(io.FileWorker,op_create,io_FileWorker_op_create)
NativeDef(io.FileWorker,op_close,io_FileWorker_op_close)
NativeDef(io.FileWorker,is_running,io_FileWorker_is_running)
NativeDef(io.FileWorker,get_buff_size,io_FileWorker_get_buff_size)
NativeDef(io.FileWorker,get_buff,io_FileWorker_get_buff)
NativeDef(io.FileWorker,get_result,io_FileWorker_get_result)
NativeDef(io.FileWorker,await,io_FileWorker_await)
NativeDef(io.FileWorker,close,io_FileWorker_close)
NativeDef(io.FileWorker,close_when_complete,io_FileWorker_close_when_complete)
NativeDef(io.FileWorker,dup_fd,io_FileWorker_dup_fd)
NativeDef(io.NetStream,get_default_ip_version,io_NetStream_get_default_ip_version)
#endif
NativeDef(io.PttyStream,new_impl,io_PttyStream_new_impl)
#if UNIX
NativeDef(io.PttyStream,prepare_slave,io_PttyStream_prepare_slave)
NativeDef(io.PttyStream,set_size,io_PttyStream_set_size)
#endif
#if MSWIN32
NativeDef(io.WindowsFileSystem,getdcwd,io_WindowsFileSystem_getdcwd)
NativeDef(io.WindowsFileSystem,get_roots,io_WindowsFileSystem_get_roots)
NativeDef(io.WinsockStream,accept_impl,io_WinsockStream_accept_impl)
NativeDef(io.WinsockStream,bind,io_WinsockStream_bind)
NativeDef(io.WinsockStream,close,io_WinsockStream_close)
NativeDef(io.WinsockStream,connect,io_WinsockStream_connect)
NativeDef(io.WinsockStream,dns_query,io_WinsockStream_dns_query)
NativeDef(io.WinsockStream,in,io_WinsockStream_in)
NativeDef(io.WinsockStream,listen,io_WinsockStream_listen)
NativeDef(io.WinsockStream,get_peer,io_WinsockStream_get_peer)
NativeDef(io.WinsockStream,get_local,io_WinsockStream_get_local)
NativeDef(io.WinsockStream,out,io_WinsockStream_out)
NativeDef(io.WinsockStream,shutdown,io_WinsockStream_shutdown)
NativeDef(io.WinsockStream,set_blocking_mode,io_WinsockStream_set_blocking_mode)
NativeDef(io.WinsockStream,new_impl,io_WinsockStream_new_impl)
NativeDef(io.WinsockStream,sendto,io_WinsockStream_sendto)
NativeDef(io.WinsockStream,recvfrom_impl,io_WinsockStream_recvfrom_impl)
NativeDef(io.WinsockStream,setopt,io_WinsockStream_setopt)
NativeDef(io.WinsockStream,getopt,io_WinsockStream_getopt)
#endif
NativeDef(lang.Class,complete_raw_instance,lang_Class_complete_raw_instance)
NativeDef(lang.Class,create_raw_instance_of,lang_Class_create_raw_instance_of)
NativeDef(lang.Class,create_raw_instance,lang_Class_create_raw_instance)
NativeDef(lang.Class,create_instance,lang_Class_create_instance)
NativeDef(lang.Class,ensure_initialized,lang_Class_ensure_initialized)
NativeDef(lang.Class,get,lang_Class_get)
NativeDef(lang.Class,get_class_flags,lang_Class_get_class_flags)
NativeDef(lang.Class,get_field_defining_class,lang_Class_get_field_defining_class)
NativeDef(lang.Class,get_field_flags,lang_Class_get_field_flags)
NativeDef(lang.Class,get_field_index,lang_Class_get_field_index)
NativeDef(lang.Class,get_field_location_impl,lang_Class_get_field_location_impl)
NativeDef(lang.Class,get_field_name,lang_Class_get_field_name)
NativeDef(lang.Class,get_implemented_classes,lang_Class_get_implemented_classes)
NativeDef(lang.Class,get_methp_object,lang_Class_get_methp_object)
NativeDef(lang.Class,get_methp_proc,lang_Class_get_methp_proc)
NativeDef(lang.Class,get_n_class_fields,lang_Class_get_n_class_fields)
NativeDef(lang.Class,get_n_instance_fields,lang_Class_get_n_instance_fields)
NativeDef(lang.Class,get_name,lang_Class_get_name)
NativeDef(lang.Class,get_class,lang_Class_get_class)
NativeDef(lang.Class,get_program,lang_Class_get_program)
NativeDef(lang.Class,get_supers,lang_Class_get_supers)
NativeDef(lang.Class,getf,lang_Class_getf)
NativeDef(lang.Class,getq,lang_Class_getq)
NativeDef(lang.Class,implements,lang_Class_implements)
NativeDef(lang.Class,load_library,lang_Class_load_library)
NativeDef(lang.Class,set_methp,lang_Class_set_methp)
NativeDef(lang.Constructor,get_field_index,lang_Constructor_get_field_index)
NativeDef(lang.Constructor,get_field_location_impl,lang_Constructor_get_field_location_impl)
NativeDef(lang.Constructor,get_field_name,lang_Constructor_get_field_name)
NativeDef(lang.Constructor,get_n_fields,lang_Constructor_get_n_fields)
NativeDef(lang.Constructor,get_name,lang_Constructor_get_name)
NativeDef(lang.Constructor,get_constructor,lang_Constructor_get_constructor)
NativeDef(lang.Constructor,get_program,lang_Constructor_get_program)
NativeDef(lang.Internal,compare,lang_Internal_compare)
NativeDef(lang.Internal,hash,lang_Internal_hash)
NativeDef(lang.Internal,order,lang_Internal_order)
NativeDef(lang.Proc,get_defining_class_impl,lang_Proc_get_defining_class_impl)
NativeDef(lang.Proc,get_field_index_impl,lang_Proc_get_field_index_impl)
NativeDef(lang.Proc,get_field_name_impl,lang_Proc_get_field_name_impl)
NativeDef(lang.Proc,get_kind_impl,lang_Proc_get_kind_impl)
NativeDef(lang.Proc,get_local_index_impl,lang_Proc_get_local_index_impl)
NativeDef(lang.Proc,get_local_location_impl,lang_Proc_get_local_location_impl)
NativeDef(lang.Proc,get_local_name_impl,lang_Proc_get_local_name_impl)
NativeDef(lang.Proc,get_local_kind_impl,lang_Proc_get_local_kind_impl)
NativeDef(lang.Proc,get_n_arguments_impl,lang_Proc_get_n_arguments_impl)
NativeDef(lang.Proc,get_n_dynamics_impl,lang_Proc_get_n_dynamics_impl)
NativeDef(lang.Proc,get_n_statics_impl,lang_Proc_get_n_statics_impl)
NativeDef(lang.Proc,get_name_impl,lang_Proc_get_name_impl)
NativeDef(lang.Proc,get_program_impl,lang_Proc_get_program_impl)
NativeDef(lang.Proc,has_varargs_impl,lang_Proc_has_varargs_impl)
NativeDef(lang.Proc,load,lang_Proc_load)
NativeDef(lang.Proc,get_proc_field,lang_Proc_get_proc_field)
NativeDef(lang.Decode,decode_methp_impl,lang_Decode_decode_methp_impl)
NativeDef(lang.Coexpression,get_activator,lang_Coexpression_get_activator)
NativeDef(lang.Coexpression,get_level,lang_Coexpression_get_level)
NativeDef(lang.Coexpression,get_program,lang_Coexpression_get_program)
NativeDef(lang.Coexpression,get_stack_info_impl,lang_Coexpression_get_stack_info_impl)
NativeDef(lang.Coexpression,is_main,lang_Coexpression_is_main)
NativeDef(lang.Coexpression,traceback,lang_Coexpression_traceback)
NativeDef(lang.Coexpression,print_stack,lang_Coexpression_print_stack)
NativeDef(lang.Prog,get_n_globals,lang_Prog_get_n_globals)
NativeDef(lang.Prog,get_global_flags,lang_Prog_get_global_flags)
NativeDef(lang.Prog,get_global_name,lang_Prog_get_global_name)
NativeDef(lang.Prog,get_global_impl,lang_Prog_get_global_impl)
NativeDef(lang.Prog,get_global_index,lang_Prog_get_global_index)
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
NativeDef(lang.Prog,set_timer_interval,lang_Prog_set_timer_interval)
NativeDef(lang.Prog,get_timer_interval,lang_Prog_get_timer_interval)
NativeDef(lang.Prog,get_event_impl,lang_Prog_get_event_impl)
NativeDef(lang.Prog,get_runtime_millis,lang_Prog_get_runtime_millis)
NativeDef(lang.Prog,get_startup_micros,lang_Prog_get_startup_micros)
NativeDef(lang.Prog,get_collection_info_impl,lang_Prog_get_collection_info_impl)
NativeDef(lang.Prog,get_global_collection_count,lang_Prog_get_global_collection_count)
NativeDef(lang.Prog,get_allocation_info_impl,lang_Prog_get_allocation_info_impl)
NativeDef(lang.Prog,get_region_info_impl,lang_Prog_get_region_info_impl)
NativeDef(lang.Prog,get_stack_used,lang_Prog_get_stack_used)
NativeDef(lang.Text,get_ord_range,lang_Text_get_ord_range)
NativeDef(lang.Text,create_cset,lang_Text_create_cset)
NativeDef(lang.Text,has_ord,lang_Text_has_ord)
NativeDef(lang.Text,utf8_seq,lang_Text_utf8_seq)
NativeDef(lang.Text,caseless_compare,lang_Text_caseless_compare)
NativeDef(lang.Text,consistent_compare,lang_Text_consistent_compare)
NativeDef(lang.Text,slice,lang_Text_slice)
NativeDef(lang.Text,is_ascii_string,lang_Text_is_ascii_string)
NativeDef(parser.UReader,raw_convert,parser_UReader_raw_convert)
NativeDef(util.Timezone,get_local_timezones,util_Timezone_get_local_timezones)
NativeDef(util.Timezone,get_gmt_offset_at,util_Timezone_get_gmt_offset_at)
NativeDef(util.Time,get_system_seconds,util_Time_get_system_seconds)
NativeDef(util.Time,get_system_millis,util_Time_get_system_millis)
NativeDef(util.Time,get_system_micros,util_Time_get_system_micros)
NativeDef(posix.System,execve,posix_System_execve)
#if !PLAN9
NativeDef(posix.System,environ,posix_System_environ)
#endif
NativeDef(posix.System,fork,posix_System_fork)
NativeDef(posix.System,kill,posix_System_kill)
NativeDef(posix.System,wait_impl,posix_System_wait_impl)
NativeDef(posix.System,getenv,posix_System_getenv)
NativeDef(posix.System,setenv,posix_System_setenv)
NativeDef(posix.System,unsetenv,posix_System_unsetenv)
NativeDef(posix.System,uname_impl,posix_System_uname_impl)
NativeDef(posix.System,getpid,posix_System_getpid)
NativeDef(posix.System,getppid,posix_System_getppid)
NativeDef(posix.System,getuid,posix_System_getuid)
NativeDef(posix.System,geteuid,posix_System_geteuid)
NativeDef(posix.System,getgid,posix_System_getgid)
NativeDef(posix.System,getegid,posix_System_getegid)
NativeDef(posix.System,getgroups,posix_System_getgroups)
NativeDef(posix.System,getpw_impl,posix_System_getpw_impl)
NativeDef(posix.System,getgr_impl,posix_System_getgr_impl)
NativeDef(posix.System,setuid,posix_System_setuid)
NativeDef(posix.System,setgid,posix_System_setgid)
NativeDef(posix.System,setsid,posix_System_setsid)
NativeDef(posix.System,getsid,posix_System_getsid)
NativeDef(posix.System,setpgid,posix_System_setpgid)
NativeDef(posix.System,getpgid,posix_System_getpgid)
#if OS_DARWIN
NativeDef(posix.System,getcwd,posix_System_getcwd)
#endif
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
