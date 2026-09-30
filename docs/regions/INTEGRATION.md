# Integration of regions r01–r07

The region branches were merged into `main` in this order: r01 (ak_core), r02 (ak_text), r03
(ak_format and web_infra), r06 (text_codec), r04 (gc), r05 (web_url), then r07 (web_unicode) in
a second pass. Each region's own notes are in `docs/regions/rNN.md`. This file records what the
merge changed to make the regions fit, what is still unported, and why nothing is gated.

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
- Every ak test block used to call a `noinline` function that held its body, because of
  compiler-issues/ranges_facts_cubic (the ak test build took more than 25 minutes). Luce 0.8.13
  fixed it; the bodies are back in the test blocks and ak's tests build and run in seconds.
- Test fragments over about 600 lines are split: `tests_hash_map`, `tests_time_2`,
  `tests_json_2` and `tests_format_2`.
- The test gates are removed:
  - `ak_core_is_ported` and `ak_format_is_ported` (r02's tests_support);
  - `ak_format_tests_use_other_regions` (r03's tests_format);
  - `web_infra_tests_use_other_regions` (r03's tests_strings).

  Every test they guarded runs.
- `test.sh` always checks and runs every module's tests and both test programs:
  - the text_codec and web_url tests used to run with `--native`, because of the interpreter's
    quadratic start-up on large global arrays (compiler-issues/interpreter_global_array_quadratic);
    that is fixed, and they run as `luce-base test` in a few seconds;
  - ak and gc natively anyway, because they contain `asm`.
- `docs/namemap.tsv` is sorted in byte order. It is the union of r02's, r04's and r05's rows
  (r01, r03 and r06 added none), plus the integration's rows:
  - `AK::WeakPtr`;
  - `is_one_of_ignoring_ascii_case`;
  - the Time formatters;
  - `(integration: …)` additions.

  `make_weak_ptr` moved to ak.

### r07 (web_unicode)

- **Merge conflicts.** `ak/ORDER` lost `stub_r07_web_unicode.lucb`. `test.sh` keeps the
  integration's structure and adds web_unicode's tests and the `tools/gen_ucd` regenerate-and-
  compare step. `docs/namemap.tsv` took r07's 13 moved rows by a three-way row merge:
  AK::String/Utf16String methods that now live in web_unicode.
- **ak cleanup.** ak's unused `Icu78UnicodeString` (`types_generated_unistr.lucb`) and
  `EmptyOrStringOrIcu78UnicodeString` are dropped, with their namemap rows.
- **ak additions for web_unicode.** `ak.StringStringViewTraits` (`HashCompatibleTraits[String,
  StringView]`) lets `is_locale_available` look up its `HashTable<String>` by a StringView, as
  the donor does.
- **Stand-ins replaced by ak:**
  - the Locale parsers use ak's `GenericLexer[u8]` (with `is_any_of("-_")`, `ignore`,
    `retreat(n)`, `consume_until`, `consume_specific`) instead of r07's `LocaleLexer`;
  - `Vector<StringView>` locals are `ak.Vector[ak.StringView]` instead of `ViewList`;
  - `vector_items` is `ak.vector_span_const`.
- **A real bug the new tests found.** `locale_data_canonicalize` kept the keys of "yes" keywords
  as views into a short String on the stack, so `en-u-ka-yes-kb-yes` restored "yes" on the wrong
  keyword. The keys are now a `HashTable<String>`, as the donor's `HashTable<ByteString>`.
- **Tests now through the real AK String entry points.** TestUnicodeNormalization, TestIDNA's
  `to_ascii`, TestSegmenter's String cases and `expand_range_case_insensitive` go through
  `normalize`, `idna_to_ascii`, `for_each_boundary(String)` and the returned Vector.
- **TestLocale's remaining cases** are ported in `tests_locale_2`: the five
  `parse_unicode_locale_id*` cases, `canonicalize_unicode_locale_id` and
  `supports_locale_aliases`.
- The web_url tests' `web_unicode_is_ported` gate is removed: all 66 run.
- web_unicode's generated upcast methods are `pub`, like the other modules'.

## After integration

### Interned strings (ak)

- **The bug.** The FlyString and Utf16FlyString tables are module globals, but interning stored
  the String's own data, and the table's buckets, in whatever allocator was current. luce-base's
  test runner makes a fresh fixed buffer current for each test, so a string interned in one test
  dangled in the next, and downstream tests had to run under `with memory.heap:`. The same held
  for FlyStrings cached in module variables, such as css_data's `string_from_property_id`.
- **The design.** The tables and every interned string live in `memory.heap`, whatever
  allocator is current. It outlives every allocator scope, as the donor's `Singleton` table
  outlives everything:
  - on a miss, `fly_string_table_add` and `utf16_fly_string_table_add` copy the data into
    `memory.heap` and intern the copy. The C++ interns the String's own data. The copy is never
    a substring, so it points at nothing in the collected heap;
  - every table change (`hash_table_set` and `did_destroy_*`'s remove) runs under
    `with memory.heap:`. Lookups do not allocate.

  A FlyString is therefore valid wherever it is kept: under any allocator, in a module global,
  or in a cell. The collector ignores its pointer into `memory.heap`.
- **FIXME: interned strings are never released.** In the donor, interned data is reference
  counted, and its destructor removes it from the table. Weak entries would need interned data
  in the collected heap, a blob finalizer that calls `did_destroy_fly_string_data`, and a
  `heap_destroy` that drops a heap's entries. gc has no blob finalizers (cells only), so the
  tables grow by every distinct string longer than 7 bytes that is interned. Revisit when gc
  gains blob finalizers.
- **Tests.**
  - `interned_strings_outlive_the_allocator_that_was_current` (tests_fly_string, and its
    Utf16FlyString twin) interns 40 strings under a `FixedBuffer`, enough for the table to grow.
    It then leaves the scope, overwrites the buffer, and checks the strings, the count and
    re-interning. Before the fix, both tests trapped.
  - tests_fly_string no longer wraps its tests in `with memory.heap:`.
  - tests_utf16_fly_string resets the table only at the start of a test, to count from zero as
    the donor does.

### `CaseInsensitiveAsciiStringViewTraits` (ak)

It conforms to `ak.Traits[StringView]`, as `AK::CaseInsensitiveASCIIStringViewTraits` derives
from `Traits<StringView>`, so it can be a HashMap's or HashTable's traits.
`case_insensitive_traits_key_a_hash_map` (tests_string_view) tests it.

## Remaining stubs and unported cases

No region stub fragment is left in any module.

The following trap by design and are not region work:

- `ak.DefaultTraits` (`support.lucb`);
- Variant's parameter-pack functions;
- the one `TODO` in `format_parameters` (a C++ `TODO()`).

Not ported, because web_unicode canonicalizes locales by syntax only (no CLDR alias data, see
`r07.md`): the 57 `canonicalize_unicode_locale_id` cases of TestLocale that need CLDR aliases.
They are the ks, ms, tz and ca value aliases, t's m0 alias, and the language, territory,
script, variant, subdivision and complex subtag aliases. They stay in `tests_locale_2` as
comments marked "CLDR alias, not ported".

## Gated tests

None. Every test block runs.

## Compiler issues found at integration

- `compiler-issues/ranges_facts_cubic.lucb`: the native backend's range pass is cubic in the
  bounds checks that dominate each other in one function. Test blocks called once from `main`
  are inlined into it. Fixed in Luce 0.8.13; the `noinline` test bodies described above are gone.
- Not needed by `test.sh`: with Luce 0.8.22, `luce-base test --backend=c` of ak and of every
  module that imports it is rejected by the C compiler: the C backend does not declare a
  top-level `let` before another top-level `let` takes its address (ak's stream vtables and
  class infos name each other: "use of undeclared identifier ..._12stream_class").
