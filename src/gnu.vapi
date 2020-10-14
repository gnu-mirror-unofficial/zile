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

[CCode(cprefix = "", lower_case_cprefix = "", cheader_filename = "regex.h")]
namespace Regex {
	[SimpleType]
#if _REGEX_LARGE_OFFSETS
	[IntegerType (rank = 9)]
#else
	[IntegerType (rank = 7)]
#endif
	public struct __re_size_t {}

	[SimpleType]
	[IntegerType (rank = 9)]
	public struct __re_long_size_t {}

	[Flags]
	[CCode (cname = "reg_syntax_t", cprefix = "RE_", has_type_id = false, feature_test_macro = "_GNU_SOURCE")]
	[IntegerType (rank = 9)]
	public enum Syntax {
		BACKSLASH_ESCAPE_IN_LISTS,
		BK_PLUS_QM,
		CHAR_CLASSES,
		CONTEXT_INDEP_ANCHORS,
		CONTEXT_INDEP_OPS,
		CONTEXT_INVALID_OPS,
		DOT_NEWLINE,
		DOT_NOT_NULL,
		HAT_LISTS_NOT_NEWLINE,
		INTERVALS,
		LIMITED_OPS,
		NEWLINE_ALT,
		NO_BK_BRACES,
		NO_BK_PARENS,
		NO_BK_REFS,
		NO_BK_VBAR,
		NO_EMPTY_RANGES,
		UNMATCHED_RIGHT_PAREN_ORD,
		NO_POSIX_BACKTRACKING,
		NO_GNU_OPS,
		DEBUG,
		INVALID_INTERVAL_ORD,
		ICASE,
		CARET_ANCHORS_HERE,
		CONTEXT_INVALID_DUP,
		NO_SUB,
		PLAIN // FIXME: GNU Zile extension
	}

	[CCode (cname = "re_syntax_options")]
	public Syntax syntax_options;

	[CCode (cprefix = "RE_SYNTAX_", lower_case_cprefix = "RE_SYNTAX_", feature_test_macro = "_GNU_SOURCE")]
	namespace SyntaxType {
		public const Syntax EMACS;
		public const Syntax AWK;
		public const Syntax GNU_AWK;
		public const Syntax POSIX_AWK;
		public const Syntax GREP;
		public const Syntax EGREP;
		public const Syntax POSIX_EGREP;
		public const Syntax ED;
		public const Syntax SED;
		public const Syntax _POSIX_COMMON;
		public const Syntax POSIX_BASIC;
		public const Syntax POSIX_MINIMAL_BASIC;
		public const Syntax POSIX_EXTENDED;
		public const Syntax POSIX_MINIMAL_EXTENDED;
	}

	[CCode (cname = "RE_DUP_MAX", feature_test_macro = "_GNU_SOURCE")]
	public const ulong DUP_MAX;

	[Flags]
	[CCode (cprefix = "REG_", has_type_id = false)]
	public enum Cflags {
		REG_EXTENDED,
		REG_ICASE,
		REG_NEWLINE,
		REG_NOSUB
	}

	[Flags]
	[CCode (cprefix = "REG_", has_type_id = false)]
	public enum Eflags {
		REG_NOTBOL,
		REG_NOTEOL,
		REG_STARTEND
	}

	/* This is defined as a private enumeration in regex.h. */
	[SimpleType]
	[IntegerType (rank = 7)]
	public struct reg_errcode_t {}

	[CCode (feature_test_macro = "_XOPEN_SOURCE")] /* || __USE_XOPEN2K, but can't express that in VAPI. */
	public const int REG_ENOSYS;
	/* (The following do not depend on the above feature test.) */
	public const int REG_NOERROR;
	public const int REG_NOMATCH;
	public const int REG_BAD;
	public const int REG_ECOLLATE;
	public const int REG_ECTYPE;
	public const int REG_EESCAPE;
	public const int REG_ESUBREG;
	public const int REG_EBRACK;
	public const int REG_EPAREN;
	public const int REG_EBRACE;
	public const int REG_BADBR;
	public const int REG_ERANGE;
	public const int REG_ESPACE;
	public const int REG_BADRPT;
	public const int REG_EEND;
	public const int REG_ESIZE;
	public const int REG_ERPAREN;

	[CCode (cname = "struct re_pattern_buffer", destroy_function = "regfree")]
	public struct Pattern {
		void *buffer;
		__re_long_size_t allocated;
		__re_long_size_t used;
		Syntax syntax;
		unowned string fastmap;
		void *translate;
		size_t re_nsub;
		bool can_be_null;
		BufferRegs regs_allocated;
		bool fastmap_accurate;
		bool no_sub;
		bool not_bol;
		bool not_eol;
		bool newline_anchor;
	}

	[CCode (cprefix = "REGS_", feature_test_macro = "_GNU_SOURCE")]
	public enum BufferRegs {
		UNALLOCATED,
		REALLOCATE,
		FIXED
	}

	[CCode (cname = "regex_t", destroy_function = "regfree")]
	public struct Regex : Pattern {}

	[SimpleType]
	[CCode (cname = "regoff_t")]
#if _REGEX_LARGE_OFFSETS
	[IntegerType (rank = 8)]
#else
	[IntegerType (rank = 6)]
#endif
	public struct Offset {}

	[CCode (cname = "struct re_registers", feature_test_macro = "_GNU_SOURCE")]
	public struct Registers {
		public __re_size_t num_regs;
		public Offset *start;
		public Offset *end;

		public void free () {
			Posix.free (start);
			Posix.free (end);
		}
	}

	[CCode (feature_test_macro = "_GNU_SOURCE")]
	public const int RE_NREGS;

	[CCode (cname = "regmatch_t")]
	public struct Match {
		public Offset rm_so;  /* Byte offset from string's start to substring's start.  */
		public Offset rm_eo;  /* Byte offset from string's start to substring's end.  */
	}

	[CCode (cname = "re_set_syntax", feature_test_macro = "_GNU_SOURCE")]
	public Syntax set_syntax (Syntax __syntax);

	[CCode (cname = "re_compile_pattern", feature_test_macro = "_GNU_SOURCE")]
	public unowned string? compile_pattern (string __pattern, size_t __length,
											out Pattern __buffer);

	[CCode (cname = "re_compile_fastmap", feature_test_macro = "_GNU_SOURCE")]
	public int compile_fastmap (Pattern *__buffer);

	[CCode (cname = "re_search", feature_test_macro = "_GNU_SOURCE")]
	public Offset search (Pattern *__buffer,
						  string __String, Offset __length,
						  Offset __start, Offset __range,
						  Registers *__regs);

	[CCode (cname = "re_search_2", feature_test_macro = "_GNU_SOURCE")]
	public Offset search_2 (Pattern *__buffer,
							string __string1, Offset __length1,
							string __string2, Offset __length2,
							Offset __start, Offset __range,
							Registers *__regs,
							Offset __stop);

	[CCode (cname = "re_match", feature_test_macro = "_GNU_SOURCE")]
	public Offset match (Pattern *__buffer,
						 string __String, Offset __length,
						 Offset __start, Registers *__regs);

	[CCode (cname = "re_match_2", feature_test_macro = "_GNU_SOURCE")]
	public Offset match_2 (Pattern *__buffer,
						   string __string1, Offset __length1,
						   string __string2, Offset __length2,
						   Offset __start, Registers *__regs,
						   Offset __stop);

	[CCode (cname = "re_set_registers", feature_test_macro = "_GNU_SOURCE")]
	public void set_registers (Pattern *__buffer,
							   Registers *__regs,
							   __re_size_t __num_regs,
							   Offset *__starts, Offset *__ends);

	/* BSD APIs.
	 *  Condition includes || (defined _LIBC && defined __USE_MISC), but
	 *  can't express that in VAPI. */
	[CCode (feature_test_macro = "_REGEX_RE_COMP")]
	public char *re_comp (string re);
	[CCode (feature_test_macro = "_REGEX_RE_COMP")]
	public int re_exec (string re);

	/* POSIX APIs.  */
	public int regcomp (Regex * __preg, string __pattern, int __cflags);

	public int regexec (Regex * __preg,
						string __String, size_t __nmatch,
						Match[] __pmatch,
						int __eflags);

	public size_t regerror (int __errcode, Regex * __preg,
							char[] __errbuf, size_t __errbuf_size);

	public void regfree (Regex *__preg);
}

[CCode (cheader_filename = "string.h", feature_test_macro = "_GNU_SOURCE")]
public string memmem (string haystack, size_t haystack_len, string needle, size_t needle_len);
