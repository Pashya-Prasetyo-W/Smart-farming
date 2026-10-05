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
        Schema::create('task_resources', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('task_id')->constrained()->cascadeOnDelete();
            $table->foreignId('resource_id')->constrained()->restrictOnDelete();
            $table->decimal('max_allocated_qty', 10, 2);
            $table->decimal('actual_used_qty', 10, 2)->nullable();
            $table->decimal('variance_qty', 10, 2)->default(0);
            $table->boolean('is_over_allocated')->default(false);
            $table->timestamps();
            $table->unique(['task_id', 'resource_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('task_resources');
    }
};
