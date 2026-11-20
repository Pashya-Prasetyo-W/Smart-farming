<?php

namespace App\Enums;

enum ReviewStatus: string
{
    case Menunggu = 'menunggu';
    case Terverifikasi = 'terverifikasi';
    case Ditolak = 'ditolak';
    case Keberatan = 'keberatan';
}
