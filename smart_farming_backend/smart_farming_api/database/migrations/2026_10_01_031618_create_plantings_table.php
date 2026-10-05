<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('plantings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('land_id')->constrained()->cascadeOnDelete();
            $table->string('crop_name');
            $table->date('plant_date');
            $table->date('est_harvest_date');
            $table->enum('status', ['berjalan', 'panen', 'gagal'])->default('berjalan');
            $table->decimal('total_cost', 15, 2)->default(0);
            $table->timestamps();
            $table->index(['company_id', 'status']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('plantings');
    }
};
