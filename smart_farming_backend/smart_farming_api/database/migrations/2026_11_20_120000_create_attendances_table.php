<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('attendances', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->date('work_date');
            $table->timestamp('check_in_at');
            $table->timestamp('check_out_at')->nullable();
            $table->string('source', 20)->default('mandiri');
            $table->foreignId('recorded_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('status', 20)->default('menunggu');
            $table->string('reviewer_role', 20);
            $table->timestamp('reviewer_assigned_at');
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->string('reviewed_role', 20)->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->string('reject_reason')->nullable();
            $table->string('objection_note')->nullable();
            $table->unsignedTinyInteger('objection_count')->default(0);
            $table->boolean('is_final')->default(false);
            $table->timestamp('escalated_at')->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'work_date']);
            $table->index(['company_id', 'status', 'reviewer_role']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('attendances');
    }
};
