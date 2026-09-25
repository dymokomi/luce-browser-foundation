# luce-browser-foundation

The foundations of the luce-browser port of Ladybird: the AK subset, LibGC, the LibUnicode pieces LibWeb uses, LibTextCodec, LibURL and the WHATWG Infra helpers, in luce-base.

Part of the luce-browser family, a faithful port of Ladybird's LibWeb to luce-base; the design every
porter follows is [DESIGN.md](../luce-browser-engine/docs/DESIGN.md).

| Module | Contents |
| --- | --- |
| `ak` | the AK subset LibWeb uses |
| `gc` | LibGC |
| `web_unicode` | the LibUnicode pieces LibWeb uses |
| `text_codec` | LibTextCodec |
| `web_url` | LibURL |
| `web_infra` | WHATWG Infra helpers |

Depends on: luce-std.

## Status

Skeleton: every type of the phase-1 closure is declared and every function has its generated
signature and a `trap("unported: ...")` body, grouped by region (`docs/regions.tsv`). Regions
replace their stub fragments with ported code (DESIGN.md §4.5). `docs/namemap.tsv` maps every C++
name to its Luce name; `docs/gc_fields.tsv` lists the GC pointer fields each cell must visit.

The skeleton is generated from Ladybird at `47c82b38d0` (see `PIN`) by a local tool that is not part
of this repository.

## Testing

`./test.sh` type-checks every module.

## License

BSD-2-Clause, as Ladybird; see `LICENSE`.
