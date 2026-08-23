# Put your built frontend here

Copy the **contents** of your build output into this directory — not the
folder itself. After building, you should have `spa/index.html`.

```
npm run build          # produces dist/ or build/
cp -r dist/* spa/
git add spa && git commit -m "Deploy frontend" && git push
```

```
spa/
├── index.html      ← required, the deploy fails without it
├── assets/
│   ├── index-4f2b9c.js
│   └── index-a81e33.css
└── README.md       ← this file, not uploaded
```

## How it is served

Everything here is uploaded to S3 and served through CloudFront.

- **`index.html` is never cached.** It is what points at your hashed asset
  filenames, so it has to be fetched fresh every time.
- **Everything else is cached for a year**, on the assumption your bundler
  puts a content hash in each filename. If it does not, users will get stale
  assets after a deploy.
- **Deep links work.** A request for `/settings/profile` returns `index.html`
  and your router resolves it client-side.
- **Files removed here are removed from S3** on the next deploy.

## Calling your backend

Use relative paths. Anything under `/api/` is routed to the backend
container rather than to S3:

```js
fetch("/api/users")
```

There is no API base URL to configure, and no CORS setup, because the
browser only ever talks to one origin.
