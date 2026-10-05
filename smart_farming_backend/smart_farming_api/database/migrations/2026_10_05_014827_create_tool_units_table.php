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
        Schema::create('tool_units', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('tool_id')->constrained()->cascadeOnDelete();
            $table->string('unit_code');
            $table->enum('condition', ['baik', 'rusak', 'perbaikan'])->default('baik');
            $table->boolean('is_available')->default(true);
            $table->timestamps();
            $table->unique(['tool_id', 'unit_code']);
            $table->index(['company_id', 'condition']);
            $table->index(['tool_id', 'is_available']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('tool_units');
    }
};
