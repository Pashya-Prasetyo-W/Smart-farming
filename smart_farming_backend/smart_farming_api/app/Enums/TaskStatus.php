<?php

namespace App\Enums;

enum TaskStatus: string
{
    case Menunggu = 'menunggu';
    case Dikerjakan = 'dikerjakan';
    case Selesai = 'selesai';
    case Gagal = 'gagal';
    case Batal = 'batal';
}
