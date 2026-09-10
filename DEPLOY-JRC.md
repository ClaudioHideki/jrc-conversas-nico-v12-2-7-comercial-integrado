# JRC Conversas 4.16.2 — publicação no GHCR

Imagem principal:

`ghcr.io/claudiohideki/jrcconversas:v4.16.2-jrc.1`

O workflow `.github/workflows/publish-ghcr.yml` pode ser executado manualmente em **Actions → Publicar imagem JRC Conversas no GHCR → Run workflow**.

O build publica duas tags:

- `v4.16.2-jrc.1`
- `lab`

O build está configurado para `linux/amd64`, compatível com o servidor atual do Dokploy.
