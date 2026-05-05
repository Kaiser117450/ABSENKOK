# tools/legacy

Folder untuk script & artifact ad-hoc yang pernah dipakai sekali untuk
hot-fix codebase, tapi tidak pernah dipanggil oleh build/test/run flow
saat ini. Disimpan untuk historical reference, **bukan** untuk dijalankan
ulang.

## fix_scripts/

Berkas-berkas Python di folder `fix_scripts/` adalah script transformasi
tekstual yang pernah dipakai untuk batch-edit file Dart/TypeScript di
masa lalu (mis. memperbaiki tanda kurung, mengubah method signature,
dll). Tidak ada satu pun yang dipanggil dari `pubspec.yaml`,
`package.json`, `astro.config.mjs`, atau pipeline CI. Aman untuk dihapus
sepenuhnya jika sudah tidak diperlukan untuk arkeologi git history.
