// The window's color depth. Unless asked, Qt takes the first EGL config that
// the compositor offers, which under cage is 16-bit (RGB565), and gradients,
// such as the backdrop's, then show bands. Call before the application starts.
#pragma once

#include <QSurfaceFormat>

inline void requestFullColor()
{
    QSurfaceFormat format = QSurfaceFormat::defaultFormat();
    format.setRedBufferSize(8);
    format.setGreenBufferSize(8);
    format.setBlueBufferSize(8);
    QSurfaceFormat::setDefaultFormat(format);
}
