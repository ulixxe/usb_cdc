def data_dump(data, col=16):
    import ctypes
    
    s = ''
    n = 0
    lines = []

    if len(data) == 0:
        return '<empty>'

    for i in range(0, len(data), col):
        line = ''
        line += '%04x: ' % (i)
        n += col

        for j in range(n-col, n):
            if j >= len(data): break
            line += '%02x ' % abs(data[j])

        line += ' ' * (3 * col + 6 - len(line)) + '| '

        for j in range(n-col, n):
            if j >= len(data): break
            c = data[j] if not (data[j] < 0x20 or data[j] > 0x7e) else '.'
            line += '%c' % c

        lines.append(line)
    return '\n'.join(lines)

