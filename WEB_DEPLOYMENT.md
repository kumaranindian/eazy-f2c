# F2C Web Deployment Guide

Complete guide for deploying the F2C Flutter Web Application.

---

## 🌐 Web-Specific Configuration

### Firebase Hosting Setup

1. **Initialize Firebase Hosting**

```bash
firebase init hosting
```

Select:
- Use an existing project
- Public directory: `build/web`
- Configure as single-page app: **Yes**
- Set up automatic builds: **No**

2. **Configure firebase.json**

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      },
      {
        "source": "**/*.@(jpg|jpeg|gif|png|svg|webp)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      }
    ]
  }
}
```

---

## 🚀 Building for Production

### 1. Build the Web App

```bash
# Development
flutter build web -t lib/main_dev.dart

# Testing
flutter build web -t lib/main_test.dart

# UAT
flutter build web -t lib/main_uat.dart

# Production
flutter build web -t lib/main_prod.dart --release
```

### 2. Optimize Build

For production, use these flags:

```bash
flutter build web \
  -t lib/main_prod.dart \
  --release \
  --web-renderer canvaskit \
  --pwa-strategy offline-first
```

**Renderer Options:**
- `canvaskit` - Better performance, larger download
- `html` - Smaller size, good for simple UIs
- `auto` - Flutter decides based on device

---

## 🔥 Firebase Deployment

### Deploy to Development

```bash
firebase use f2c-dev
flutter build web -t lib/main_dev.dart
firebase deploy --only hosting
```

### Deploy to Testing

```bash
firebase use f2c-test
flutter build web -t lib/main_test.dart
firebase deploy --only hosting
```

### Deploy to UAT

```bash
firebase use f2c-uat
flutter build web -t lib/main_uat.dart
firebase deploy --only hosting
```

### Deploy to Production

```bash
firebase use f2c-prod
flutter build web -t lib/main_prod.dart --release
firebase deploy --only hosting
```

---

## 🌍 Custom Domain Setup

### 1. Add Custom Domain in Firebase Console

1. Go to Firebase Console → Hosting
2. Click "Add custom domain"
3. Enter your domain (e.g., `app.f2c.com`)
4. Follow DNS configuration steps

### 2. DNS Configuration

Add these records to your DNS:

```
Type: A
Name: @
Value: (Firebase IP addresses provided)

Type: A
Name: www
Value: (Firebase IP addresses provided)
```

### 3. SSL Certificate

Firebase automatically provisions SSL certificates for custom domains.

---

## 🔧 Environment-Specific Deployments

### Multiple Hosting Sites

Create separate hosting sites for each environment:

```bash
# Create hosting sites
firebase hosting:sites:create f2c-dev
firebase hosting:sites:create f2c-test
firebase hosting:sites:create f2c-uat
firebase hosting:sites:create f2c-prod
```

### Update firebase.json

```json
{
  "hosting": [
    {
      "site": "f2c-dev",
      "public": "build/web",
      "rewrites": [{"source": "**", "destination": "/index.html"}]
    },
    {
      "site": "f2c-test",
      "public": "build/web",
      "rewrites": [{"source": "**", "destination": "/index.html"}]
    },
    {
      "site": "f2c-uat",
      "public": "build/web",
      "rewrites": [{"source": "**", "destination": "/index.html"}]
    },
    {
      "site": "f2c-prod",
      "public": "build/web",
      "rewrites": [{"source": "**", "destination": "/index.html"}]
    }
  ]
}
```

### Deploy to Specific Site

```bash
firebase deploy --only hosting:f2c-dev
firebase deploy --only hosting:f2c-prod
```

---

## 📊 Performance Optimization

### 1. Enable Compression

Firebase Hosting automatically compresses files.

### 2. Lazy Loading

Already implemented in the code with proper routing.

### 3. Image Optimization

- Use WebP format for images
- Compress images before adding to assets
- Use CDN for large media files

### 4. Code Splitting

Flutter Web automatically splits code for better loading.

### 5. Caching Strategy

Configure in `web/index.html`:

```html
<meta http-equiv="Cache-Control" content="max-age=31536000">
```

---

## 🔒 Security Headers

Add security headers in `firebase.json`:

```json
{
  "hosting": {
    "headers": [
      {
        "source": "**",
        "headers": [
          {
            "key": "X-Content-Type-Options",
            "value": "nosniff"
          },
          {
            "key": "X-Frame-Options",
            "value": "DENY"
          },
          {
            "key": "X-XSS-Protection",
            "value": "1; mode=block"
          },
          {
            "key": "Referrer-Policy",
            "value": "strict-origin-when-cross-origin"
          }
        ]
      }
    ]
  }
}
```

---

## 🧪 Testing Deployment

### Local Testing

```bash
# Build
flutter build web -t lib/main_dev.dart

# Serve locally
firebase serve --only hosting

# Or use Flutter's built-in server
flutter run -d chrome -t lib/main_dev.dart
```

### Preview Before Deploy

```bash
firebase hosting:channel:deploy preview-$(date +%s)
```

---

## 📱 Progressive Web App (PWA)

### Manifest Configuration

Already configured in `web/manifest.json`:

```json
{
  "name": "F2C - Farm2Community",
  "short_name": "F2C",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#2E7D32",
  "theme_color": "#2E7D32"
}
```

### Service Worker

Flutter automatically generates service worker for offline support.

### Install Prompt

Users can install the web app on their devices:
- Chrome: Add to Home Screen
- Safari: Add to Home Screen
- Edge: Install App

---

## 🔄 CI/CD for Web

### GitHub Actions Example

```yaml
name: Deploy to Firebase Hosting

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: 'stable'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Build web
        run: flutter build web -t lib/main_prod.dart --release
      
      - name: Deploy to Firebase
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
          projectId: f2c-prod
```

---

## 📈 Monitoring

### Firebase Analytics

Already integrated. Monitor:
- Page views
- User engagement
- Custom events

### Performance Monitoring

```bash
firebase deploy --only hosting,performance
```

### Error Tracking

Consider integrating:
- Sentry
- Firebase Crashlytics (for web)

---

## 🌐 Browser Compatibility

### Supported Browsers

- ✅ Chrome 90+
- ✅ Firefox 88+
- ✅ Safari 14+
- ✅ Edge 90+

### Polyfills

Flutter Web includes necessary polyfills automatically.

---

## 🔧 Troubleshooting

### Build Issues

```bash
# Clean build
flutter clean
flutter pub get
flutter build web -t lib/main_prod.dart --release
```

### Deployment Issues

```bash
# Check Firebase login
firebase login

# Verify project
firebase projects:list

# Check hosting status
firebase hosting:sites:list
```

### CORS Issues

Configure in Firebase Console:
- Storage → CORS configuration
- Add allowed origins

---

## 📋 Deployment Checklist

- [ ] Build web app for production
- [ ] Test locally with `firebase serve`
- [ ] Verify Firebase project selected
- [ ] Check environment variables
- [ ] Deploy to Firebase Hosting
- [ ] Verify deployment URL
- [ ] Test all features
- [ ] Check performance metrics
- [ ] Configure custom domain (if needed)
- [ ] Set up SSL certificate
- [ ] Enable security headers
- [ ] Configure caching
- [ ] Test on multiple browsers
- [ ] Monitor analytics

---

## 🚀 Quick Deployment Commands

### Development
```bash
flutter build web -t lib/main_dev.dart && firebase use f2c-dev && firebase deploy --only hosting
```

### Production
```bash
flutter build web -t lib/main_prod.dart --release && firebase use f2c-prod && firebase deploy --only hosting
```

---

## 📞 Support

For deployment issues:
1. Check Firebase Console logs
2. Review browser console errors
3. Verify Firebase configuration
4. Check network tab for failed requests

---

**Your F2C web app is ready to deploy! 🎉**
