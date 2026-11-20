<?php

namespace App\Enums;

enum AttendanceStatus: string
{
    case Menunggu = 'menunggu';
    case Terverifikasi = 'terverifikasi';
    case Ditolak = 'ditolak';
    case Keberatan = 'keberatan';
}
