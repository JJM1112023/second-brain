#!/usr/bin/env bash

# ═══════════════════════════════════════════════════════════
#   MULTI-AGENT SYSTEM — FINAL VERIFICATION SCRIPT
# ═══════════════════════════════════════════════════════════

# Must be run from the project root; cd there automatically when invoked via path.
cd "$(dirname "$0")" || { echo "ERROR: cannot cd to script directory"; exit 1; }

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
TOKEN=""
API_KEY=""

log_pass() { echo -e "  ${GREEN}✅ PASS${NC} — $1"; ((PASS++)); }
log_fail() { echo -e "  ${RED}❌ FAIL${NC} — $1"; ((FAIL++)); }
log_warn() { echo -e "  ${YELLOW}⚠️  WARN${NC} — $1"; ((WARN++)); }
log_info() { echo -e "  ${CYAN}ℹ️  INFO${NC} — $1"; }
section()  { echo -e "\n${BOLD}${BLUE}$1${NC}"; echo "$(printf '─%.0s' {1..55})"; }

# ───────────────────────────────────────────────────────────
section "📦 [1/8] CHECKING PREREQUISITES"
# ───────────────────────────────────────────────────────────

# Docker
if command -v docker &>/dev/null; then
  VER=$(docker --version | grep -Eo '[0-9]+\.[0-9]+' | head -1)
  log_pass "Docker installed → $VER"
else
  log_fail "Docker not found — install Docker Desktop"
fi

# Docker Compose
if docker compose version &>/dev/null 2>&1; then
  log_pass "Docker Compose v2 available"
elif docker-compose version &>/dev/null 2>&1; then
  log_warn "docker-compose v1 found (use 'docker compose' v2)"
else
  log_fail "Docker Compose not found"
fi

# Python
if command -v python3 &>/dev/null; then
  PY=$(python3 --version)
  log_pass "Python installed → $PY"
else
  log_fail "Python3 not found"
fi

# .env file
if [ -f ".env" ]; then
  log_pass ".env file exists"
  if grep -q "ANTHROPIC_API_KEY=sk-ant" .env; then
    log_pass "ANTHROPIC_API_KEY looks valid"
  else
    log_fail "ANTHROPIC_API_KEY missing or invalid in .env"
  fi
else
  log_fail ".env file not found — create it first"
fi

# Key Python files
KEY_FILES=(
  "api/gateway.py"
  "api/routes/auth_routes.py"
  "api/routes/agent_routes.py"
  "agents/base_agent.py"
  "agents/coding_agent.py"
  "agents/research_agent.py"
  "agents/data_agent.py"
  "orchestrator/orchestrator.py"
  "communication/message_bus.py"
  "monitoring/metrics.py"
  "monitoring/collectors.py"
  "docker-compose.yml"
  "Dockerfile"
  "requirements.txt"
)
MISSING=0
for f in "${KEY_FILES[@]}"; do
  [ ! -f "$f" ] && log_fail "Missing: $f" && ((MISSING++))
done
[ $MISSING -eq 0 ] && log_pass "All required source files present"

# __init__.py checks
INIT_DIRS=("api" "api/auth" "api/routes" "api/middleware"
           "agents" "orchestrator" "communication"
           "monitoring" "ui" "ui/components")
MISSING_INITS=0
for d in "${INIT_DIRS[@]}"; do
  [ ! -f "$d/__init__.py" ] && ((MISSING_INITS++))
done
if [ $MISSING_INITS -eq 0 ]; then
  log_pass "All __init__.py files present"
else
  log_fail "$MISSING_INITS missing __init__.py files"
  log_info "Run: find . -type d | xargs -I{} touch {}/__init__.py"
fi

# ───────────────────────────────────────────────────────────
section "🐳 [2/8] CHECKING DOCKER CONTAINERS"
# ───────────────────────────────────────────────────────────

EXPECTED=("agent_api" "agent_redis" "agent_prometheus"
          "agent_grafana" "agent_ui")

for container in "${EXPECTED[@]}"; do
  STATUS=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)
  if [ "$STATUS" = "running" ]; then
    HEALTH=$(docker inspect -f '{{.State.Health.Status}}' \
             "$container" 2>/dev/null)
    if [ -z "$HEALTH" ]; then
      log_pass "$container is running (no healthcheck configured)"
    elif [ "$HEALTH" != "healthy" ]; then
      log_warn "$container is running but health=$HEALTH"
    else
      log_pass "$container is running"
    fi
  elif [ -z "$STATUS" ]; then
    log_fail "$container doesn't exist — run: docker compose up -d"
  else
    log_fail "$container status=$STATUS (expected: running)"
  fi
done

# Port checks
PORTS=(8000 8502 9090 3000 6379)
NAMES=("API Gateway" "Streamlit UI" "Prometheus" "Grafana" "Redis")
for i in "${!PORTS[@]}"; do
  PORT=${PORTS[$i]}
  NAME=${NAMES[$i]}
  if nc -z localhost "$PORT" 2>/dev/null || \
     curl -s --max-time 1 "http://localhost:$PORT" &>/dev/null; then
    log_pass "Port $PORT open → $NAME"
  else
    log_fail "Port $PORT not reachable → $NAME may be down"
  fi
done

# ───────────────────────────────────────────────────────────
section "🌐 [3/8] CHECKING API GATEWAY"
# ───────────────────────────────────────────────────────────

# Health endpoint
HEALTH=$(curl -sf --max-time 5 http://localhost:8000/health 2>/dev/null)
if echo "$HEALTH" | grep -q '"healthy"'; then
  log_pass "GET /health → healthy"
else
  log_fail "GET /health failed (response: $HEALTH)"
fi

# Docs endpoint
DOCS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
              --max-time 5 http://localhost:8000/docs 2>/dev/null)
if [ "$DOCS_STATUS" = "200" ]; then
  log_pass "GET /docs → 200 OK (Swagger UI available)"
else
  log_fail "GET /docs returned HTTP $DOCS_STATUS"
fi

# Root endpoint
ROOT=$(curl -sf --max-time 5 http://localhost:8000/ 2>/dev/null)
if echo "$ROOT" | grep -q "Multi-Agent"; then
  log_pass "GET / → API root responding"
else
  log_warn "GET / response unexpected: $ROOT"
fi

# Metrics endpoint
METRICS=$(curl -sf --max-time 5 http://localhost:8000/metrics 2>/dev/null)
if echo "$METRICS" | grep -q "# HELP"; then
  log_pass "GET /metrics → Prometheus metrics available"
  for metric in "agent_tasks_total" "http_requests_total" \
                "active_agents_count" "llm_api_calls_total"; do
    if echo "$METRICS" | grep -q "$metric"; then
      log_pass "  Metric exists: $metric"
    else
      log_warn "  Metric not found: $metric"
    fi
  done
else
  log_fail "GET /metrics failed or empty"
fi

# ───────────────────────────────────────────────────────────
section "🔐 [4/8] CHECKING AUTHENTICATION"
# ───────────────────────────────────────────────────────────

# Load credentials from .env
# Anchored grep + -f2- preserves values that contain = (e.g. base64 passwords).
# Explicit empty-check fallback because the pipeline exit code is tr's (always 0).
ADMIN_USER=$(grep "^ADMIN_USERNAME=" .env 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"')
[ -z "$ADMIN_USER" ] && ADMIN_USER="admin"
ADMIN_PASS=$(grep "^ADMIN_PASSWORD=" .env 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"')
[ -z "$ADMIN_PASS" ] && ADMIN_PASS="admin123"

# JWT Login
LOGIN_RESP=$(curl -sf --max-time 10 \
  -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\"}" \
  2>/dev/null)

if echo "$LOGIN_RESP" | grep -q "access_token"; then
  log_pass "POST /auth/login → JWT token received"
  TOKEN=$(echo "$LOGIN_RESP" | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" \
    2>/dev/null)
  ROLE=$(echo "$LOGIN_RESP" | \
    python3 -c "import sys,json; print(json.load(sys.stdin)['role'])" \
    2>/dev/null)
  log_info "Role: $ROLE"
else
  log_fail "POST /auth/login failed → $LOGIN_RESP"
fi

# Test /auth/me with JWT
if [ -n "$TOKEN" ]; then
  ME=$(curl -sf --max-time 5 \
    http://localhost:8000/auth/me \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null)
  if echo "$ME" | grep -q "username"; then
    log_pass "GET /auth/me → authenticated as $ADMIN_USER"
  else
    log_fail "GET /auth/me failed with valid token"
  fi
fi

# Invalid credential test
BAD=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"nobody","password":"wrong"}' 2>/dev/null)
if [ "$BAD" = "401" ]; then
  log_pass "Invalid login correctly returns 401"
else
  log_warn "Invalid login returned $BAD (expected 401)"
fi

# Generate API Key
if [ -n "$TOKEN" ]; then
  KEY_RESP=$(curl -sf --max-time 10 \
    -X POST http://localhost:8000/auth/api-keys \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"role":"developer","rate_limit":200}' 2>/dev/null)

  if echo "$KEY_RESP" | grep -q "api_key"; then
    log_pass "POST /auth/api-keys → API key generated"
    API_KEY=$(echo "$KEY_RESP" | \
      python3 -c "import sys,json; print(json.load(sys.stdin)['api_key'])" \
      2>/dev/null)
    log_info "Key preview: ${API_KEY:0:20}..."
  else
    log_fail "API key generation failed → $KEY_RESP"
  fi
fi

# ───────────────────────────────────────────────────────────
section "🤖 [5/8] CHECKING AGENTS (SYNC MODE)"
# ───────────────────────────────────────────────────────────

if [ -z "$API_KEY" ]; then
  log_warn "No API key — skipping agent tests (auth failed)"
else

  # Coding Agent
  log_info "Testing Coding Agent (30s timeout)..."
  CODING=$(curl -sf --max-time 60 \
    -X POST http://localhost:8000/agents/coding \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"task":"Print the numbers 1 to 5 using Python","async_mode":false}' \
    2>/dev/null)

  CODING_STATUS=$(echo "$CODING" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); \
    print(d.get('status','unknown'))" 2>/dev/null)

  if [ "$CODING_STATUS" = "completed" ]; then
    log_pass "POST /agents/coding → completed successfully"
    CODING_JOB=$(echo "$CODING" | \
      python3 -c "import sys,json; \
      print(json.load(sys.stdin).get('job_id',''))" 2>/dev/null)
    [ -n "$CODING_JOB" ] && log_info "Job ID: $CODING_JOB"
  else
    log_fail "Coding agent failed → $CODING"
  fi

  # Research Agent
  log_info "Testing Research Agent (30s timeout)..."
  RESEARCH=$(curl -sf --max-time 60 \
    -X POST http://localhost:8000/agents/research \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"task":"In one sentence, what is Python?","async_mode":false}' \
    2>/dev/null)

  RESEARCH_STATUS=$(echo "$RESEARCH" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); \
    print(d.get('status','unknown'))" 2>/dev/null)
  if [ "$RESEARCH_STATUS" = "completed" ]; then
    log_pass "POST /agents/research → completed successfully"
  else
    log_fail "Research agent failed → $(echo "$RESEARCH" | head -c 200)"
  fi

  # Data Agent
  log_info "Testing Data Agent (30s timeout)..."
  DATA=$(curl -sf --max-time 60 \
    -X POST http://localhost:8000/agents/data \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"task":"Create a SQLite DB called test.db with a users table (id, name, age). Insert 3 rows. Query all rows.","async_mode":false}' \
    2>/dev/null)

  DATA_STATUS=$(echo "$DATA" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); \
    print(d.get('status','unknown'))" 2>/dev/null)
  if [ "$DATA_STATUS" = "completed" ]; then
    log_pass "POST /agents/data → completed successfully"
  else
    log_fail "Data agent failed → $(echo "$DATA" | head -c 200)"
  fi

  # Async Job Test
  log_info "Testing async job submission..."
  ASYNC=$(curl -sf --max-time 10 \
    -X POST http://localhost:8000/agents/coding \
    -H "X-API-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"task":"Print hello world","async_mode":true}' \
    2>/dev/null)

  ASYNC_JOB=$(echo "$ASYNC" | \
    python3 -c "import sys,json; \
    print(json.load(sys.stdin).get('job_id',''))" 2>/dev/null)

  if [ -n "$ASYNC_JOB" ]; then
    log_pass "POST /agents/coding (async) → job_id: $ASYNC_JOB"

    log_info "Polling job status..."
    for i in {1..10}; do
      sleep 3
      JOB_DATA=$(curl -sf --max-time 5 \
        "http://localhost:8000/agents/jobs/$ASYNC_JOB" \
        -H "X-API-Key: $API_KEY" 2>/dev/null)
      JOB_STATUS=$(echo "$JOB_DATA" | \
        python3 -c "import sys,json; \
        print(json.load(sys.stdin).get('status',''))" 2>/dev/null)

      if [ "$JOB_STATUS" = "completed" ]; then
        log_pass "GET /agents/jobs/$ASYNC_JOB → completed ✓"
        break
      elif [ "$JOB_STATUS" = "failed" ]; then
        log_fail "Job $ASYNC_JOB failed"
        break
      else
        log_info "  Attempt $i/10 — status: $JOB_STATUS"
      fi
    done
  else
    log_fail "Async job submission failed → $ASYNC"
  fi
fi

# ───────────────────────────────────────────────────────────
section "📋 [6/8] CHECKING JOB MANAGEMENT"
# ───────────────────────────────────────────────────────────

if [ -n "$API_KEY" ]; then
  JOBS=$(curl -sf --max-time 5 \
    http://localhost:8000/agents/jobs \
    -H "X-API-Key: $API_KEY" 2>/dev/null)

  JOB_COUNT=$(echo "$JOBS" | \
    python3 -c "
import sys, json
d = json.load(sys.stdin)
j = d.get('jobs')
print(len(j) if isinstance(j, (dict, list)) else -1)
" 2>/dev/null)
  if [ -n "$JOB_COUNT" ] && [ "$JOB_COUNT" -ge 0 ] 2>/dev/null; then
    log_pass "GET /agents/jobs → $JOB_COUNT jobs found"
  else
    log_fail "GET /agents/jobs failed"
  fi

  # Admin metrics
  ADMIN_METRICS=$(curl -sf --max-time 5 \
    http://localhost:8000/admin/metrics \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null)

  if echo "$ADMIN_METRICS" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if 'system' in d else 1)" 2>/dev/null; then
    log_pass "GET /admin/metrics → system metrics available"
    CPU=$(echo "$ADMIN_METRICS" | \
      python3 -c "import sys,json; \
      d=json.load(sys.stdin); \
      print(d.get('system',{}).get('cpu_percent',0))" 2>/dev/null)
    MEM=$(echo "$ADMIN_METRICS" | \
      python3 -c "import sys,json; \
      d=json.load(sys.stdin); \
      print(d.get('system',{}).get('memory_percent',0))" 2>/dev/null)
    log_info "System: CPU=${CPU}% | Memory=${MEM}%"
  else
    log_fail "GET /admin/metrics failed"
  fi
fi

# ───────────────────────────────────────────────────────────
section "📊 [7/8] CHECKING MONITORING STACK"
# ───────────────────────────────────────────────────────────

# Prometheus targets
PROM_TARGETS=$(curl -sf --max-time 5 \
  http://localhost:9090/api/v1/targets 2>/dev/null)

if echo "$PROM_TARGETS" | grep -q "activeTargets"; then
  log_pass "Prometheus API responding"

  UP_COUNT=$(echo "$PROM_TARGETS" | \
    python3 -c "
import sys, json
d = json.load(sys.stdin)
targets = d.get('data',{}).get('activeTargets',[])
up = sum(1 for t in targets if t.get('health') == 'up')
total = len(targets)
print(f'{up}/{total}')
" 2>/dev/null)
  log_info "Targets up: $UP_COUNT"

  if echo "$PROM_TARGETS" | \
    python3 -c "
import sys,json
d=json.load(sys.stdin)
targets=d.get('data',{}).get('activeTargets',[])
ok=[t for t in targets if t.get('health')=='up' \
    and 'api_gateway' in str(t.get('labels',''))]
exit(0 if ok else 1)
" 2>/dev/null; then
    log_pass "API Gateway target is UP in Prometheus"
  else
    log_warn "API Gateway not showing as UP in Prometheus"
    log_info "Check: http://localhost:9090/targets"
  fi
else
  log_fail "Prometheus not responding"
fi

# Prometheus query
PROM_QUERY=$(curl -sf --max-time 5 \
  "http://localhost:9090/api/v1/query?query=up" 2>/dev/null)
if echo "$PROM_QUERY" | grep -q "result"; then
  log_pass "Prometheus queries working"
else
  log_fail "Prometheus query engine not responding"
fi

# Grafana
GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  --max-time 5 http://localhost:3000 2>/dev/null)
if [ "$GRAFANA_STATUS" = "200" ] || \
   [ "$GRAFANA_STATUS" = "302" ]; then
  log_pass "Grafana responding (HTTP $GRAFANA_STATUS)"
else
  log_fail "Grafana not responding (HTTP $GRAFANA_STATUS)"
fi

# Grafana datasource
GRAFANA_PASS=$(grep "^GRAFANA_PASSWORD=" .env 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"')
[ -z "$GRAFANA_PASS" ] && GRAFANA_PASS="admin123"
GRAFANA_DS=$(curl -sf --max-time 5 \
  -u "admin:$GRAFANA_PASS" \
  http://localhost:3000/api/datasources 2>/dev/null)
if echo "$GRAFANA_DS" | grep -q "Prometheus"; then
  log_pass "Grafana → Prometheus datasource configured"
else
  log_warn "Grafana datasource not found (may need manual setup)"
fi

# Streamlit UI
UI_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  --max-time 5 http://localhost:8502 2>/dev/null)
if [ "$UI_STATUS" = "200" ]; then
  log_pass "Streamlit UI responding (HTTP 200)"
else
  log_fail "Streamlit UI not responding (HTTP $UI_STATUS)"
fi

# ───────────────────────────────────────────────────────────
section "🗄️ [8/8] CHECKING REDIS"
# ───────────────────────────────────────────────────────────

REDIS_PING=$(docker exec agent_redis redis-cli ping 2>/dev/null)
if [ "$REDIS_PING" = "PONG" ]; then
  log_pass "Redis PING → PONG"

  REDIS_INFO=$(docker exec agent_redis \
    redis-cli info server 2>/dev/null)
  REDIS_VER=$(echo "$REDIS_INFO" | \
    grep "redis_version" | cut -d: -f2 | tr -d '\r')
  log_info "Redis version:$REDIS_VER"

  REDIS_KEYS=$(docker exec agent_redis \
    redis-cli dbsize 2>/dev/null)
  log_info "Keys stored: $REDIS_KEYS"

  REDIS_MEM=$(docker exec agent_redis \
    redis-cli info memory 2>/dev/null | \
    grep "used_memory_human" | cut -d: -f2 | tr -d '\r')
  log_info "Memory used:$REDIS_MEM"
else
  log_fail "Redis not responding to PING"
fi

# Redis write/read test — capture SET output to distinguish write vs read failures
SET_OUT=$(docker exec agent_redis \
  redis-cli set test_verify "hello" EX 10 2>/dev/null)
READ_BACK=$(docker exec agent_redis \
  redis-cli get test_verify 2>/dev/null)
if [ "$READ_BACK" = "hello" ]; then
  log_pass "Redis read/write test passed"
elif [ "$SET_OUT" != "OK" ]; then
  log_fail "Redis write failed (SET returned: $SET_OUT)"
else
  log_fail "Redis read failed after successful write"
fi

# ───────────────────────────────────────────────────────────
section "📊 FINAL RESULTS"
# ───────────────────────────────────────────────────────────

TOTAL=$((PASS + FAIL + WARN))

echo ""
echo "  Total checks : $TOTAL"
echo -e "  ${GREEN}Passed${NC}        : $PASS"
echo -e "  ${RED}Failed${NC}        : $FAIL"
echo -e "  ${YELLOW}Warnings${NC}      : $WARN"
echo ""

if [ $FAIL -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}🎉 ALL CHECKS PASSED! System is fully operational.${NC}"
  echo ""
  echo "  🌐 Open these in your browser:"
  echo "     🤖 http://localhost:8502  (Streamlit UI)"
  echo "     📖 http://localhost:8000/docs (API Docs)"
  echo "     📊 http://localhost:3000  (Grafana)"
  echo "     🔭 http://localhost:9090  (Prometheus)"
elif [ $FAIL -le 2 ]; then
  echo -e "  ${YELLOW}${BOLD}⚠️  MOSTLY WORKING — $FAIL minor issue(s) to fix.${NC}"
  echo "  Check FAIL items above and see troubleshoot below."
else
  echo -e "  ${RED}${BOLD}❌ $FAIL CHECKS FAILED — System needs attention.${NC}"
  echo "  Run: docker compose logs -f to debug"
fi

echo ""
echo "════════════════════════════════════════════════════════"
