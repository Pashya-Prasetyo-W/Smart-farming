<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('worker_benefit_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('type', 20);
            $table->string('name');
            $table->string('description')->nullable();
            $table->timestamps();
            $table->index(['user_id', 'type']);
        });

        if (Schema::hasTable('worker_benefits')) {
            $now = now();
            $rows = [];

            $legacy = DB::table('worker_benefits')
                ->join('users', 'users.id', '=', 'worker_benefits.user_id')
                ->where('users.role', 'mandor')
                ->select('worker_benefits.*')
                ->get();

            foreach ($legacy as $benefit) {
                if ($benefit->health_insurance) {
                    $rows[] = [
                        'company_id'  => $benefit->company_id,
                        'user_id'     => $benefit->user_id,
                        'type'        => 'kesehatan',
                        'name'        => $benefit->health_insurance_desc ?: 'Jaminan Kesehatan',
                        'description' => null,
                        'created_at'  => $now,
                        'updated_at'  => $now,
                    ];
                }

                if ($benefit->food_allowance) {
                    $rows[] = [
                        'company_id'  => $benefit->company_id,
                        'user_id'     => $benefit->user_id,
                        'type'        => 'makan',
                        'name'        => $benefit->food_allowance_desc ?: 'Tunjangan Makan',
                        'description' => null,
                        'created_at'  => $now,
                        'updated_at'  => $now,
                    ];
                }
            }

            if ($rows !== []) {
                DB::table('worker_benefit_items')->insert($rows);
            }

            Schema::drop('worker_benefits');
        }
    }

    public function down(): void
    {
        Schema::create('worker_benefits', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            $table->boolean('health_insurance')->default(false);
            $table->string('health_insurance_desc')->nullable();
            $table->boolean('food_allowance')->default(false);
            $table->string('food_allowance_desc')->nullable();
            $table->timestamps();
        });

        Schema::dropIfExists('worker_benefit_items');
    }
};
