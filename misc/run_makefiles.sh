#!/bin/zsh

# 执行各文件夹下的Makefile，并行执行，监视Error关键字
# 如果发现Error关键字则停止
# 使用: ./run_makefiles.sh [最大并行数]

MAX_JOBS="${1:-4}"

# 获取所有包含Makefile的文件夹
declare -a DIRS
for dir in */; do
    if [[ -f "$dir/Makefile" ]] || [[ -f "$dir/makefile" ]]; then
        DIRS+=("${dir%/}")
    fi
done

if [[ ${#DIRS[@]} -eq 0 ]]; then
    echo "未找到包含Makefile的文件夹"
    exit 1
fi

echo "找到 ${#DIRS[@]} 个Makefile，最多 $MAX_JOBS 个并行"
echo ""

# 设置中断处理
cleanup() {
    echo ""
    echo "收到中断信号，停止所有进程..."
    kill $(jobs -p) 2>/dev/null
    exit 1
}
trap cleanup SIGINT SIGTERM

declare -A PIDS
declare -A DIRS_MAP
job_count=0

# 启动所有make进程
for dir in "${DIRS[@]}"; do
    # 等待直到有空闲的并行槽位
    while [[ $(jobs -r | wc -l) -ge $MAX_JOBS ]]; do
        sleep 0.1
    done
    
    echo "启动: $dir"
    (
        cd "$dir" || exit 1
        make 2>&1 | tee "/tmp/make_${dir}.log"
    ) &
    
    local pid=$!
    PIDS[$pid]=$dir
    ((job_count++))
done

echo ""
echo "正在执行 $job_count 个任务..."
echo ""

# 监视所有进程的输出，检查Error
failed=0
completed=0

while [[ $completed -lt $job_count ]]; do
    for pid in "${!PIDS[@]}"; do
        if ! kill -0 $pid 2>/dev/null; then
            # 进程已完成
            dir="${PIDS[$pid]}"
            
            # 检查日志中是否有Error
            if grep -i "error" "/tmp/make_${dir}.log" > /dev/null; then
                echo "❌ $dir 发现 Error 关键字"
                failed=1
                unset PIDS[$pid]
                ((completed++))
            else
                echo "✓ $dir 完成"
                unset PIDS[$pid]
                ((completed++))
            fi
        fi
    done
    
    # 如果发现Error，停止所有进程
    if [[ $failed -eq 1 ]]; then
        echo ""
        echo "发现Error，停止所有进程..."
        kill $(jobs -p) 2>/dev/null
        wait
        exit 1
    fi
    
    sleep 0.5
done

echo ""
echo "✅ 所有Makefile执行完成，未发现Error"
