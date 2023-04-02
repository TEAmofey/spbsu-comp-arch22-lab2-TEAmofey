M = 64
N = 60
K = 32

a = [[0] * K for _ in range(M)]  # array a
b = [[0] * N for _ in range(K)]  # array b
c = [[0] * N for _ in range(M)]  # array c

offset = 0
tagset = 0

for i in range(M):
    for j in range(K):
        a[i][j] = tagset
        offset += 1
        if offset % 16 == 0:
            tagset += 1
            offset = 0

for i in range(K):
    for j in range(N):
        b[i][j] = tagset
        offset += 2
        if offset % 16 == 0:
            tagset += 1
            offset = 0

for i in range(M):
    for j in range(N):
        c[i][j] = tagset
        offset += 4
        if offset % 16 == 0:
            tagset += 1
            offset = 0

cache = [[0] * 2 for _ in range(64)]

for i in range(64):
    cache[i][0] = -1

misses = 0  # количество промахов
requests = 32 * 64 * 60 * 2 + 64 * 60  # количество запросов всего
clock = 0  # количество тактов


def f(line_adr: int) -> int:
    global clock
    st = line_adr % 32
    if cache[2 * st][0] == line_adr:  # первая линия нужная
        clock += 6  # время отклика кэша при попадании
        cache[2 * st][1] = 1
        cache[2 * st + 1][1] = 0
        return 0  # попали
    if cache[2 * st + 1][0] == line_adr:  # вторая линия нужная
        clock += 6  # время отклика кэша при попадании
        cache[2 * st + 1][1] = 1
        cache[2 * st][1] = 0
        return 0  # попали
    if cache[2 * st][1] == 0:  # первая линия использовалась давно
        clock += 112  # 4 + 100 + 8
        # наша линия грязная, когда в ней лежит элемент из c[][]
        if cache[2 * st][0] >= 368:
            clock += 101  # 100 + 1
        cache[2 * st][0] = line_adr
        cache[2 * st][1] = 1
        cache[2 * st + 1][1] = 0
        return 1  # промах
    if cache[2 * st + 1][1] == 0:  # вторая линия использовалась давно
        clock += 112  # 4 + 100 + 8
        # наша линия грязная, когда в ней лежит элемент из c[][]
        if cache[2 * st + 1][0] >= 368:
            clock += 101  # 100 + 1
        cache[2 * st + 1][0] = line_adr
        cache[2 * st + 1][1] = 1
        cache[2 * st][1] = 0
        return 1  # промах
    assert False  # невозможное состояние


clock += 1  # initialisation pa
clock += 1  # initialisation pc
clock += 1  # initialisation y
for m in range(M):
    clock += 1  # iteration
    clock += 1  # y++
    clock += 1  # initialisation x
    for n in range(N):
        clock += 1  # iteration
        clock += 1  # x++
        clock += 1  # initialisation pb
        clock += 1  # initialisation s
        clock += 1  # initialisation k
        for k in range(K):
            clock += 1  # iteration
            clock += 1  # k++
            misses += f(a[m][k])
            clock += 1  # end of op
            misses += f(b[k][n])
            clock += 1  # end of op
            clock += 5  # mult
            clock += 2  # sum
        misses += f(c[m][n])
        clock += 1  # end of op
    clock += 2  # sum
clock += 1  # end of func

print("Всего обращений к кэшу:", requests)
print("Всего промахов:", misses)
print("Процент попаданя:", (requests - misses) / requests)
print("Количество тактов:", clock)
