<?php

namespace App\Enums;

enum UserRole: string
{
    case Pemilik = 'pemilik';
    case Mandor = 'mandor';
    case Buruh = 'buruh';

    public static function values(): array
    {
        return array_map(fn (self $role) => $role->value, self::cases());
    }
}
