# Integration of regions r01–r06

The region branches were merged into `main` in this order: r01 (ak_core), r02 (ak_text), r03
(ak_format and web_infra), r06 (text_codec), r04 (gc), r05 (web_url). Region r07 (web_unicode) is
**not** merged: `web_unicode` is still the skeleton's stubs. Each region's own notes are in
`docs/regions/rNN.md`. This file records what the merge changed to make the regions fit, what is
still a stub, and which tests stay gated.

## What the merge changed

### r01 against r02 (ak)

- **ORDER and imports.** `ak/ORDER` lists both regions' fragments, then the stubs, then the tests.
  The module-wide imports live in `ak/module.lucb`. r02's `import memory` is dropped, and its
  `import strings` becomes `import strings as number_strings`, because r01's tests use `strings`
  as a local name.
- **`string_hash`.**
  - r01's two functions are kept: `string_hash` for `char` and `string_hash_u16` for `char16_t`.
    r02's `string_hash[u8]` and `string_hash[u16]` calls use them.
  - `string_hash` and `case_insensitive_string_hash` sign-extend bytes ≥ 0x80, as the donor's
    signed `char` does. `char16_t` does not sign-extend.
  - `tests_integer_math` pins the values, taken from the donor's `AK::string_hash` compiled
    locally.
  - r01's pinned hash and iteration-order tests pass unchanged.
- **HashTable lookups.** r01's HashTable is faithful: `find` answers an iterator. The FlyString
  and Utf16FlyString table lookups therefore:
  - pass an `ak.Function1` predicate, built from a capture struct and a function;
  - compare the iterator with `end()`;
  - dereference the iterator, as the C++ does.
- **StringBuilder.**
  - `leak_buffer_for_string_construction` answers `ByteBufferOutlineBuffer?`, the C++
    `Optional<OutlineBuffer>`.
  - `string_builder_init_fields` default-constructs `m_buffer`, so a builder constructed on
    uninitialised memory is empty. `gc`'s `dump_graph` found this.
- **LineTrackingLexer** reads r01's `RedBlackTreeIterator::key` directly.
- **Test helpers.** `tests_support`'s Vector readers use `vector_at_const` and `vector_size`.

### r03 against r01/r02 (ak, web_infra)

- r03's edits to the r01/r02 stub fragments went away with the stubs. Its calls now use the
  ported names:
  - `generic_lexer_*_t_char_type`;
  - `parse_first_number_string_view_f64`;
  - `string_view_to_number_u64` and `string_view_to_number_i64`;
  - `convert_to_decimal_exponential_form_f32` and `_f64`;
  - `pow_integral_u64` and `log2_u8`;
  - `decode_single_or_paired_surrogate`'s `UnicodeEscapeResult`.
- Duplicates are removed:
  - r03's own `pow_u64` and `log2_u8`;
  - the `pthread_self` extern;
  - `sv_of`, now `ak.sv`;
  - `size_max`, now `usize_max`.
- `string_view_text` is `pub`, and it prints non-UTF-8 bytes as a marker.
- `import c` is `import c as libc`. `from luce import Comparable, Equatable` moved to
  `module.lucb`. r01's locals named `out` are renamed, because `AK::out` is now a function.
- **Real bugs the ungated tests found:**
  - `JsonArray`'s constructor did not default-construct `m_values`.
  - The test helpers `formatted`, `text_of_string` (ak) and `text_of` (web_infra, web_url tests)
    returned a `str` into a short String's or a StringBuilder's inline bytes, which live in the
    helper's frame. They copy the bytes out now.
  - `Checked<i8>` and `Checked<i16>` have no arithmetic in r01, so `format_checked` sets their
    overflow flag directly.
- **Ported at integration.** `Formatter<Duration>` (AK/Time.cpp) and `Formatter<UnixDateTime>`
  (AK/Time.h) need both Time and Format, so no region owned them. They are in
  `ak/time_format.lucb`. TestFormat's `format_duration` and TestTime's `time_to_string` and
  `formatter_unix_date_time` now run.

### r06 (text_codec)

- `text_codec/ak_support.lucb` is removed. Its stand-ins are the real ak functions:
  - `ak.sv`, `ak.function1_call`, `ak.dbgln` and `ak.string_view_text`;
  - `ak.binary_search`: the gb18030 comparators take the needle by pointer, as a `Function2`.
- `StringView::is_one_of_ignoring_ascii_case` is added to ak (`string_view.lucb`). The C++
  parameter pack of literals is a `str` span.
- StreamingDecoder's constructor initialises `m_pending_input`, the C++ default member. The
  ported streaming tests found this.

### r04 (gc)

- `gc/ak_support.lucb` is removed. Its stand-ins are the real ak functions:
  - `ak.sv`, `ak.dbgln` and `ak.string_view_text`;
  - `ak.function0_call` and `ak.function1_call`;
  - `ak.stack_info_construct`;
  - `ak.get_random_uniform`.

  r04's stand-in had a Windows branch that r01's `csprng` lacked. `csprng` now has it, through
  `os.random_bytes`.
- **Atomic allocation hook.** `heap_construct` installs `heap_atomic_allocator(heap)` as
  `ak.atomic_allocator`, and `heap_destroy` removes it. While a heap exists on a thread, ak's
  atomic storage (string bytes, ByteBuffers) is that heap's atomic blobs. As DESIGN.md §3.3 rule
  4 says, the ak values that own it must then live in managed memory or on the stack. In the
  tests that means running under `with heap`.
- **Container visitors and WeakHashSet.**
  - The visitors walk AK's containers through ak's iterators (the C++ range-for):
    `hash_table_begin_const`, `ordered_hash_table_begin`, `hash_map_begin_const` and
    `ordered_hash_map_begin_const`. They no longer read bucket fields.
  - WeakHashSet's iterator wraps a `HashTableIterator`.
  - `maybe_prune` is `remove_all_matching`, as in the donor.
  - ak's iterator methods (`iterator`, `next`) are `pub`, so that other modules can walk ak's
    containers.
- **Weak pointers.** r01 stored an `ak.WeakLink*` in `gc.Weak.m_impl`, but r04 reads that field
  as a `WeakImpl` from a weak block. Those are LibGC's weak references, which track cells only.
  - `AK::WeakPtr<T>` is therefore its own `ak.WeakPtr[T]`, holding the WeakLink as AK's does
    (`ak/weak_ptr.lucb`).
  - `make_weak_ptr` lives in ak, and `gc/weakable.lucb` is removed.
  - A WeakPtr keeps its object reachable through the scanned link, and `revoke_weak_ptrs` (the
    donor's `~Weakable`) nulls it.
  - The two LibWeb uses of `WeakPtr` point at ref-counted AK objects, not cells.
- **dump_graph.** It uses `string_number_u64` and `byte_string_number_u64`.
- **New tests:**
  - WeakHashSet, including a walk after a collection;
  - `dump_graph`'s JSON;
  - AK WeakPtr (`basic_weak`, `weakptr_move`).

### r05 (web_url)

- r05's edits to the r01/r02 stubs went away with the stubs. web_url checks against the ported
  ak as it is.
- Its stand-ins for AK templates are the real functions:
  - `AK::parse_number<u32>` is `parse_number_string_view_u32`;
  - `to_number<u16>` is `string_view_to_number_u16` or `string_to_number_u16`, with
    `TrimWhitespace::No` as in the donor;
  - `String::number` is `string_number_u64`;
  - the Vector copy is `vector_clone`.

  web_url's `sv` and `string_lit` delegate to ak. The three AK::Format integer formats LibURL
  uses (`{}`, `{:x}`, `%{:02X}`) stay written out in `web_url/support.lucb`.
- **A real bug LibURL's tests found:** r01's `vector_clone` trapped when copying an empty vector
  that has capacity. `tests_vector` has a regression test.

### Everywhere

- The generated upcast methods (`cell()`, `stream()`, `cell_visitor()`, …) are `pub` in ak, gc
  and text_codec. web_unicode is left as the skeleton made it, because r07 edits it.
- Every ak test block calls a `noinline` function that holds its body (# workaround:
  compiler-issues/ranges_facts_cubic). Without this, the ak test build takes more than 25
  minutes; with it, the whole of `./test.sh` runs in about 1.5 minutes.
- Test fragments over about 600 lines are split: `tests_hash_map`, `tests_time_2`,
  `tests_json_2` and `tests_format_2`.
- The test gates are removed:
  - `ak_core_is_ported` and `ak_format_is_ported` (r02's tests_support);
  - `ak_format_tests_use_other_regions` (r03's tests_format);
  - `web_infra_tests_use_other_regions` (r03's tests_strings).

  Every test they guarded runs.
- `test.sh` always checks and runs every module's tests and both test programs:
  - the text_codec and web_url tests with `--native`, because of the interpreter's quadratic
    start-up on large global arrays;
  - ak and gc natively anyway, because they contain `asm`.
- `docs/namemap.tsv` is sorted in byte order. It is the union of r02's, r04's and r05's rows
  (r01, r03 and r06 added none), plus the integration's rows:
  - `AK::WeakPtr`;
  - `is_one_of_ignoring_ascii_case`;
  - the Time formatters;
  - `(integration: …)` additions.

  `make_weak_ptr` moved to ak.

## Remaining stubs

| Region | Where | What |
| --- | --- | --- |
| r07 web_unicode | `web_unicode/stub_r07_web_unicode.lucb` (126 functions) | all of LibUnicode: character types and properties, IDNA, normalization, segmentation, locales |
| r07 web_unicode | `ak/stub_r07_web_unicode.lucb` (13 functions) | the LibUnicode-defined AK::String / Utf16String methods (to_lowercase, to_uppercase, to_titlecase, to_casefold, to_fullwidth, equals_ignoring_case, trim_whitespace, find_byte_offset_ignoring_case); r07 moves them to `web_unicode.string_*` |

The following trap by design and are not region work:

- `ak.DefaultTraits` (`support.lucb`);
- Variant's parameter-pack functions;
- the one `TODO` in `format_parameters` (a C++ `TODO()`).

## Gated tests

`tests/web_url_tests/support.lucb` has `var web_unicode_is_ported: bool = false`. The 16 tests
below return at their start until r07 is merged. Remove the flag then.

| Test | File | Needs |
| --- | --- | --- |
| public_suffix | test_url | `Unicode::IDNA::to_ascii` (its Arabic hosts) |
| url_pattern_matches_named_groups, url_pattern_ignore_case_matching | test_url_pattern | identifier start/continue properties (pattern names) |
| basic_http_url_no_pattern_or_path, url_with_pathname_and_regexp, http_url_regexp_in_pathname_and_hostname, https_url_with_fragment, http_url_with_query, matches_on_sub_url, ipv6_with_port_number, non_special_scheme_and_arbitrary_hostname, ipv6_with_named_group | test_url_pattern_constructor_string_parser | identifier properties (the constructor string parser tokenizes names) |
| tokenizer, component_compile, pattern_create_and_match, pattern_errors | test_pinned | identifier properties |

The list was found by running the tests against non-trapping stand-ins of the three web_unicode
functions (scratch only, never committed). No other test reaches a stub.

## Region r07: not merged

The coordinator asked for r07 (port/r07 c684dd3) to be merged before r05. The permission
classifier refused that merge in this session, so r07 is left for a later merge. At that merge:

- r07 removes `ak/stub_r07_web_unicode.lucb` and moves those methods to web_unicode.
- Drop ak's now-unused `EmptyOrStringOrIcu78UnicodeString` and `Icu78UnicodeString`.
- Switch r07's `LocaleLexer` to r02's `GenericLexer[u8]`, which is faithful now.
- Remove `web_unicode_is_ported` from the web_url tests.
- Port TestLocale's parse and canonicalize cases, which need ak's String and Vector.
- Write `docs/regions/r07.md` from r07's notes.

## Compiler issues found at integration

- `compiler-issues/ranges_facts_cubic.lucb`: the native backend's range pass is cubic in the
  bounds checks that dominate each other in one function. Test blocks called once from `main`
  are inlined into it. The workaround is the `noinline` test bodies described above.
- Not reduced, and not needed by `test.sh`: `luce-base test --backend=c` crashes (SIGSEGV) on
  this package's modules (web_infra, ak), but not on a single-file test.
