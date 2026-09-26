#!/data/data/com.termux/files/usr/bin/bash

BASE="http://localhost:3000"
PASS_COUNT=0
FAIL_COUNT=0

pass(){
  echo "✅ $1"
  PASS_COUNT=$((PASS_COUNT+1))
}

fail(){
  echo "❌ $1"
  FAIL_COUNT=$((FAIL_COUNT+1))
}

echo "=============================="
echo "   TAWS﻿EEL AL-BIRK TEST"
echo "=============================="

echo
echo "1) فحص السيرفر..."
if curl -sf "$BASE" >/dev/null; then
  pass "SERVER"
else
  fail "SERVER"
  echo "شغّل npm start أولاً"
  exit 1
fi

echo
echo "2) تسجيل دخول العميل..."

CUSTOMER=$(curl -s -X POST "$BASE/api/auth/login" \
-H "Content-Type: application/json" \
-d '{"phone":"0500000000","password":"123456"}')

CUSTOMER_TOKEN=$(echo "$CUSTOMER" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$CUSTOMER_TOKEN" ]; then
  pass "CUSTOMER LOGIN"
else
  fail "CUSTOMER LOGIN"
  echo "$CUSTOMER"
  exit 1
fi

echo
echo "3) فحص حساب العميل..."

ME=$(curl -s "$BASE/api/auth/me" \
-H "Authorization: Bearer $CUSTOMER_TOKEN")

if echo "$ME" | grep -q '"role":"customer"'; then
  pass "CUSTOMER AUTH"
else
  fail "CUSTOMER AUTH"
fi

echo
echo "4) إنشاء طلب تجريبي..."

ORDER=$(curl -s -X POST "$BASE/api/orders" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer $CUSTOMER_TOKEN" \
-d '{
"serviceType":"مطاعم",
"storeName":"مطعم تجريبي",
"items":"طلب اختبار",
"note":"اختبار النظام",
"pickup":{"lat":18.2167,"lng":41.5350},
"dropoff":{"lat":18.2200,"lng":41.5400},
"paymentMethod":"cash"
}')

ORDER_ID=$(echo "$ORDER" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$ORDER_ID" ]; then
  pass "CREATE ORDER"
else
  fail "CREATE ORDER"
  echo "$ORDER"
  exit 1
fi

echo
echo "رقم الطلب التجريبي: $ORDER_ID"

echo
echo "5) تسجيل دخول المندوب..."

DRIVER=$(curl -s -X POST "$BASE/api/auth/login" \
-H "Content-Type: application/json" \
-d '{"phone":"0500000001","password":"123456"}')

DRIVER_TOKEN=$(echo "$DRIVER" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$DRIVER_TOKEN" ]; then
  pass "DRIVER LOGIN"
else
  fail "DRIVER LOGIN"
  echo "$DRIVER"
  exit 1
fi

echo
echo "6) فحص طلبات المندوب..."

DRIVER_ORDERS=$(curl -s "$BASE/api/orders" \
-H "Authorization: Bearer $DRIVER_TOKEN")

if echo "$DRIVER_ORDERS" | grep -q "$ORDER_ID"; then
  pass "DRIVER SEES ORDER"
else
  fail "DRIVER SEES ORDER"
fi

echo
echo "7) إرسال عرض المندوب..."

OFFER=$(curl -s -X POST "$BASE/api/orders/$ORDER_ID/offers" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer $DRIVER_TOKEN" \
-d '{"price":10}')

OFFER_ID=$(echo "$OFFER" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$OFFER_ID" ]; then
  pass "SEND OFFER"
else
  fail "SEND OFFER"
  echo "$OFFER"
  exit 1
fi

echo
echo "8) العميل يرى العرض..."

OFFERS=$(curl -s "$BASE/api/orders/$ORDER_ID/offers" \
-H "Authorization: Bearer $CUSTOMER_TOKEN")

if echo "$OFFERS" | grep -q "$OFFER_ID"; then
  pass "CUSTOMER SEES OFFER"
else
  fail "CUSTOMER SEES OFFER"
fi

echo
echo "9) قبول العرض..."

ACCEPT=$(curl -s -X POST \
"$BASE/api/orders/$ORDER_ID/accept-offer/$OFFER_ID" \
-H "Authorization: Bearer $CUSTOMER_TOKEN")

if echo "$ACCEPT" | grep -q '"ok":true'; then
  pass "ACCEPT OFFER"
else
  fail "ACCEPT OFFER"
  echo "$ACCEPT"
fi

echo
echo "10) بدء التوصيل..."

START=$(curl -s -X POST "$BASE/api/orders/$ORDER_ID/status" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer $DRIVER_TOKEN" \
-d '{"status":"in_delivery"}')

if echo "$START" | grep -q '"status":"in_delivery"'; then
  pass "START DELIVERY"
else
  fail "START DELIVERY"
  echo "$START"
fi

echo
echo "11) إنهاء الطلب..."

DONE=$(curl -s -X POST "$BASE/api/orders/$ORDER_ID/status" \
-H "Content-Type: application/json" \
-H "Authorization: Bearer $DRIVER_TOKEN" \
-d '{"status":"delivered"}')

if echo "$DONE" | grep -q '"status":"delivered"'; then
  pass "DELIVERED"
else
  fail "DELIVERED"
  echo "$DONE"
fi

echo
echo "=============================="
echo "الاختبارات الناجحة: $PASS_COUNT"
echo "الاختبارات الفاشلة: $FAIL_COUNT"
echo "=============================="

if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "🎉 BACKEND TEST: PASS"
else
  echo "⚠️ BACKEND TEST: يحتاج إصلاح"
fi
