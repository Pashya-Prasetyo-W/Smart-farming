<?php

namespace App\Enums;

enum TaskStatus: string
{
    case Menunggu = 'menunggu';
    case Dikerjakan = 'dikerjakan';
    case MenungguVerifikasi = 'menunggu_verifikasi';
    case Selesai = 'selesai';
    case Ditolak = 'ditolak';
    case Gagal = 'gagal';
    case Batal = 'batal';
}
