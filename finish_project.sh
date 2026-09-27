#!/data/data/com.termux/files/usr/bin/bash

set -u

echo "================================"
echo "   TAWS﻿EEL AL-BIRK FINAL"
echo "================================"

echo
echo "1) فحص الملفات..."
for f in package.json src/server.js public/index.html public/driver.html public/admin.html schema.sql; do
  if [ -f "$f" ]; then
    echo "✅ $f"
  else
    echo "❌ مفقود: $f"
    exit 1
  fi
done

echo
echo "2) التأكد من حماية .env..."
if git check-ignore .env >/dev/null 2>&1; then
  echo "✅ .env مستبعد من Git"
else
  echo "❌ تحذير: .env غير مستبعد"
  exit 1
fi

echo
echo "3) فحص JavaScript..."
node --check src/server.js
if [ $? -eq 0 ]; then
  echo "✅ server.js سليم"
else
  echo "❌ يوجد خطأ في server.js"
  exit 1
fi

echo
echo "4) تثبيت الحزم..."
npm install

echo
echo "5) تشغيل الاختبارات..."
if [ -x ./test_project.sh ]; then
  ./test_project.sh
else
  echo "⚠️ test_project.sh غير قابل للتشغيل، يتم تخطيه"
fi

echo
echo "6) تجهيز Git..."
git add .
git status

echo
echo "7) إنشاء Commit..."
if git diff --cached --quiet; then
  echo "✅ لا توجد تغييرات جديدة"
else
  git commit -m "Final production version"
fi

echo
echo "8) فحص اتصال GitHub..."
git remote -v

echo
echo "================================"
echo "المشروع جاهز للرفع والنشر ✅"
echo "================================"

echo
echo "لرفع المشروع إلى GitHub نفذ:"
echo "git push -u origin main"
