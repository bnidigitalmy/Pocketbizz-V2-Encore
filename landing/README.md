# PocketBizz Landing Page

Landing page statik untuk PocketBizz menggunakan HTML + JavaScript + Tailwind CSS (CDN).

## Struktur

- `index.html` - Halaman utama (semua content dalam satu file)
- Tailwind CSS via CDN (tiada build step diperlukan)

## Deploy

### Vercel (Paling Mudah)

1. Import repo ke Vercel: https://vercel.com → New Project → pilih `pocketbizz-landing`
2. Vercel akan auto-detect sebagai static site
3. Deploy selesai!

### Netlify

1. Import repo ke Netlify: https://app.netlify.com → Add new site → Import from Git
2. Build command: (kosong)
3. Publish directory: `/` (root)
4. Deploy!

### GitHub Pages

1. Push ke GitHub
2. Settings → Pages → Source: Deploy from branch `main`
3. Folder: `/` (root)
4. Save

### Manual (Any Static Hosting)

1. Upload `index.html` ke hosting anda
2. Selesai!

## Custom Domain

Set custom domain `pocketbizz.my` di:
- **Vercel**: Settings → Domains → Add domain
- **Netlify**: Domain settings → Add custom domain
- **GitHub Pages**: Settings → Pages → Custom domain

## Update Content

Edit `index.html` terus:
- Ganti placeholder screenshot/testimoni
- Update CTA links jika perlu
- Modify copy/messaging

## Local Preview

Buka `index.html` terus dalam browser atau gunakan local server:

```bash
# Python
python -m http.server 8000

# Node.js
npx serve

# PHP
php -S localhost:8000
```

Kemudian buka http://localhost:8000
