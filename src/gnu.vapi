/*
 * Vala binding for GNU APIs.
 *
 * Reuben Thomas 2020.
 *
 * This file is public domain.
 */

using Posix;

/* FIXME: getopt_long_fix.h works around bug https://gitlab.gnome.org/GNOME/vala/-/issues/1082 */
[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "getopt.h,getopt_long_fix.h")]
namespace GetoptLong {
	[CCode (cname = "option")]
	public struct Option {
		public unowned string name;
		public int has_arg;
		public int *flag;
		public int val;
	}

	/* Names for the values of the 'has_arg' field of 'struct option'.  */
	[CCode (cname = "no_argument")]
	public const int none;
	[CCode (cname = "required_argument")]
	public const int required;
	[CCode (cname = "optional_argument")]
	public const int optional;

	public int getopt_long ([CCode (array_length_pos = 0)] string[] args,
							string shortopts,
							[CCode (array_length = false, array_null_terminated = true)] Option[] longopts, out int longind);

	public int getopt_long_only ([CCode (array_length_pos = 0)] string[] args,
							string shortopts,
							[CCode (array_length = false, array_null_terminated = true)] Option[] longopts, out int longind);
}

[CCode (cheader_filename = "string.h", feature_test_macro = "_GNU_SOURCE")]
public string memmem (string haystack, size_t haystack_len, string needle, size_t needle_len);

[CCode (cheader_filename = "error.h")]
[PrintfFormat]
public void error (int status, int errnum, string format, ...);

[CCode (cheader_filename = "quote.h")]
public string quote (string arg);
