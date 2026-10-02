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
        Schema::create('task_reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('task_id')->unique()->constrained()->cascadeOnDelete();
            $table->json('media_urls');
            $table->decimal('actual_qty', 10, 2);
            $table->string('notes')->nullable();
            $table->datetime('reported_at');
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('task_reports');
    }
};
