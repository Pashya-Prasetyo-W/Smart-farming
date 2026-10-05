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
        Schema::create('failure_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('planting_id')->nullable()->constrained()->nullOnDelete();
            $table->enum('source', ['cronjob', 'manual'])->default('cronjob');
            $table->foreignId('input_by')->nullable()->constrained('users')->nullOnDelete();
            $table->decimal('risk_score', 5, 2);
            $table->string('reason');
            $table->json('analyzed_data_json');
            $table->timestamps();
            $table->index(['company_id', 'created_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('failure_logs');
    }
};
