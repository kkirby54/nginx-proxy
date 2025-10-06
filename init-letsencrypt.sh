#!/bin/bash

# Let's Encrypt 초기 인증서 발급 스크립트
# 사용법: ./init-letsencrypt.sh

set -e

echo "### Let's Encrypt 인증서 발급 시작 ###"
echo ""

# 변수 설정
domains="minhub.duckdns.org"
email="sdk926@gmail.com"  # 필수: 실제 이메일로 변경하세요 (만료 알림 수신용)
staging=0  # 0=실제 인증서, 1=테스트 인증서 (테스트 시 1로 변경)

# 디렉토리 확인
if [ ! -d "certbot/conf" ] || [ ! -d "certbot/www" ]; then
  echo "Error: certbot/conf 또는 certbot/www 디렉토리가 없습니다."
  echo "다음 명령어로 생성하세요: mkdir -p certbot/conf certbot/www"
  exit 1
fi

# nginx 설정 확인
echo "Step 1: nginx 설정 확인"
echo "HTTPS 서버 블록이 주석 처리되어 있는지 확인합니다..."
if grep -q "^#.*listen 443 ssl" nginx.conf; then
  echo "✓ HTTPS 블록이 주석 처리되어 있습니다."
else
  echo "⚠ 경고: HTTPS 블록이 활성화되어 있습니다."
  echo "인증서가 없으면 nginx 시작이 실패할 수 있습니다."
  echo "nginx.conf를 확인하세요."
fi
echo ""

# nginx HTTP만 시작
echo ""
echo "Step 2: nginx 시작 (HTTP만)"
docker-compose up -d nginx

# nginx 시작 대기
echo "nginx 시작 대기 중..."
sleep 5

# 인증서 발급
echo ""
echo "Step 3: Let's Encrypt 인증서 발급"
echo "도메인: $domains"
echo "이메일: $email"
echo ""

# staging 플래그 설정
staging_arg=""
if [ $staging != "0" ]; then
  staging_arg="--staging"
  echo "*** 테스트 모드: staging 인증서 발급 ***"
fi

# certbot 실행 (기존 entrypoint 무시하고 직접 실행)
docker-compose run --rm --entrypoint "" certbot certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email $email \
  --agree-tos \
  --no-eff-email \
  --force-renewal \
  $staging_arg \
  -d $domains

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ 인증서 발급 성공!"
  echo "인증서 위치: ./certbot/conf/live/$domains/"
  echo ""
  
  echo "Step 4: nginx.conf 업데이트 중..."
  echo "HTTPS 서버 블록 활성화 및 HTTP 리다이렉션 설정..."
  echo ""
  echo "⚠️  수동으로 다음 작업을 수행하세요:"
  echo ""
  echo "1. nginx.conf 편집:"
  echo "   - 67~170번째 줄: HTTPS 서버 블록 주석 해제"
  echo "   - 35~64번째 줄: 임시 HTTP 프록시 설정 삭제"
  echo "   - 62~64번째 줄: HTTPS 리다이렉션 주석 해제"
  echo ""
  echo "2. nginx 재시작:"
  echo "   docker-compose restart nginx"
  echo ""
  echo "3. certbot 시작:"
  echo "   docker-compose up -d certbot"
  echo ""
else
  echo ""
  echo "❌ 인증서 발급 실패"
  echo ""
  echo "문제 해결:"
  echo "  1. DNS 확인: nslookup $domains"
  echo "  2. 포트 80 개방 확인: curl http://$domains/.well-known/acme-challenge/test"
  echo "  3. 방화벽/NSG에서 80 포트 허용 확인"
  echo "  4. 테스트하려면 스크립트에서 staging=1로 변경"
  exit 1
fi

