<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable(['name', 'email', 'password', 'company_id', 'role'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    use HasFactory, Notifiable, HasApiTokens;

    protected $attributes = [
        'is_active'            => true,
        'must_change_password' => false,
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_active' => 'boolean',
            'must_change_password' => 'boolean',
        ];
    }

    public function hasRole(string ...$roles): bool
    {
        return in_array($this->role, $roles, true);
    }

    public function company()
    {
        return $this->belongsTo(Company::class);
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function schedule()
    {
        return $this->hasOne(WorkerSchedule::class);
    }

    public function benefits()
    {
        return $this->hasMany(WorkerBenefitItem::class)->orderBy('id');
    }

    public function wage()
    {
        return $this->hasOne(WorkerWage::class);
    }

    public function allowances()
    {
        return $this->hasMany(WorkerAllowance::class)->orderBy('id');
    }

    public function tasks()
    {
        return $this->hasMany(Task::class, 'assigned_to');
    }
}
